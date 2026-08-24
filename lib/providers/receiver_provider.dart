import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detector_model.dart';
import '../models/event_model.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';

class ReceiverProvider extends ChangeNotifier {
  bool _isScanning = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedHub;
  List<BluetoothDevice> _discoveredHubs = [];
  List<DetectorModel> _detectors = [];
  List<EventModel> _events = [];
  Map<int, String> _zoneNames = {};
  final DatabaseService _db = DatabaseService();
  final AudioService _audio = AudioService();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription? _pairingScanSubscription;
  Timer? _connectionMonitorTimer;

  // Alarm tracking
  final Map<String, DateTime> _alarmStartTimes = {};
  final Map<String, bool> _alarmBorderActive = {};
  bool _soundEnabled = true;

  // UUID сервиса/характеристик протокола концентратора. Больше НЕ
  // используются для поиска/идентификации устройства в эфире (это теперь
  // делается только по имени, см. TARGET_DEVICE_NAMES) — а нужны только
  // после подключения, чтобы понять, какая из характеристик найденного
  // GATT-сервиса за что отвечает (извещатели/события/команды).
  static const String SERVICE_UUID = "e0a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c5";
  static const String DETECTORS_CHAR_UUID =
      "e1a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c6";
  static const String EVENTS_CHAR_UUID = "e2a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c7";
  static const String COMMAND_CHAR_UUID =
      "e3a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c8";

  static const List<String> TARGET_DEVICE_NAMES = [
    "BLE Alarm Hub",
    "Alarm Hub",
    "ESP32 Alarm",
    "Security Hub",
    "BT485_EE2D"
  ];

  // Характеристика, с которой реально пришёл первый валидный пакет
  // протокола извещателей/событий (см. connectToHub) — заполняется по
  // содержимому пакета, а не по заранее известному UUID.
  BluetoothCharacteristic? _eventsChar;
  BluetoothCharacteristic? _commandChar;

  // Диагностика RAW-пакетов (см. _logRawPacket): для каждой характеристики
  // (ключ "serviceUuid/charUuid") храним последний полученный пакет и
  // порядковый номер, чтобы в лог выводить не только сами байты, но и то,
  // что именно изменилось по сравнению с предыдущим пакетом с этой же
  // характеристики. Это должно помочь понять формат протокола BT485_EE2D
  // (например, отличить heartbeat в покое от пакета реального события).
  final Map<String, List<int>> _lastRawPacket = {};
  final Map<String, int> _rawPacketSeq = {};

  // Геттеры
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedHub => _connectedHub;
  List<BluetoothDevice> get discoveredHubs => _discoveredHubs;
  List<DetectorModel> get detectors => _detectors;
  List<EventModel> get events => _events;
  Map<String, DateTime> get alarmStartTimes =>
      Map.unmodifiable(_alarmStartTimes);
  Map<String, bool> get alarmBorderActive =>
      Map.unmodifiable(_alarmBorderActive);
  bool get soundEnabled => _soundEnabled;
  Map<int, String> get zoneNames => Map.unmodifiable(_zoneNames);

  // Название зоны: пользовательское, если задано, иначе "Зона N" по умолчанию.
  String zoneName(int zone) => _zoneNames[zone] ?? 'Зона $zone';

  // Переименовать зону
  Future<void> renameZone(int zone, String name) async {
    final trimmed = name.trim();
    final effective = trimmed.isEmpty ? 'Зона $zone' : trimmed;
    _zoneNames[zone] = effective;
    notifyListeners();
    await _db.renameZone(zone, effective);
  }

  // Задать/изменить название места конкретного извещателя (окно, калитка,
  // дверь и т.д.)
  Future<void> renamePlace(String detectorId, String place) async {
    final index = _detectors.indexWhere((d) => d.id == detectorId);
    if (index == -1) return;
    final trimmed = place.trim();
    _detectors[index].place = trimmed;
    notifyListeners();
    await _db.updateDetectorPlace(detectorId, trimmed);
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  // Статистика
  int get totalDetectors => _detectors.length;
  int get activeDetectors => _detectors.where((d) => d.isActive).length;
  int get alarmDetectors =>
      _detectors.where((d) => d.status == DetectorStatus.alarm).length;
  int get tamperDetectors =>
      _detectors.where((d) => d.status == DetectorStatus.tamper).length;
  int get lowBatteryDetectors =>
      _detectors.where((d) => d.status == DetectorStatus.lowBattery).length;
  int get offlineDetectors =>
      _detectors.where((d) => d.status == DetectorStatus.offline).length;
  int get unreadEvents => _events.where((e) => !e.isRead).length;

  // Инициализация
  ReceiverProvider() {
    _loadData();
    _startConnectionMonitor();
  }

  // Загрузка данных из БД
  Future<void> _loadData() async {
    _detectors = await _db.getDetectors();
    _events = await _db.getEvents(limit: 200);
    _zoneNames = await _db.getZoneNames();
    notifyListeners();
  }

  // Мониторинг соединения
  void _startConnectionMonitor() {
    _connectionMonitorTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDetectorsOffline();
    });
  }

  // Проверка на отсутствие связи
  void _checkDetectorsOffline() {
    var now = DateTime.now();
    bool changed = false;

    for (var detector in _detectors) {
      if (detector.isActive &&
          now.difference(detector.lastSeen).inMinutes > 5 &&
          detector.status != DetectorStatus.offline) {
        detector.status = DetectorStatus.offline;
        changed = true;

        _addEvent(EventModel(
          timestamp: now,
          type: EventType.disconnected,
          detectorId: detector.id,
          detectorName: detector.name,
          description: 'Потеря связи с ${detector.name}',
        ));
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  // Запрос разрешений
  Future<bool> requestPermissions() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.notification,
      ].request();

      return statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.bluetoothConnect]!.isGranted &&
          statuses[Permission.locationWhenInUse]!.isGranted;
    } catch (e) {
      debugPrint('Ошибка запроса разрешений: $e');
      return false;
    }
  }

  // На Android platformName часто пуст во время скана —
  // реальное имя приходит в advertisementData.localName
  String scanResultName(ScanResult result) {
    final localName = result.advertisementData.localName;
    final platformName = result.device.platformName;
    return localName.isNotEmpty ? localName : platformName;
  }

  // Сравнение имени найденного устройства со списком TARGET_DEVICE_NAMES.
  // Без учёта регистра и лишних пробелов по краям — некоторые модули (в т.ч.
  // BT485_EE20) отдают имя с небольшими отличиями от того, что видно в
  // документации/на корпусе.
  bool _isTargetName(String name) {
    if (name.isEmpty) return false;
    final n = name.trim().toLowerCase();
    return TARGET_DEVICE_NAMES.any((t) => t.trim().toLowerCase() == n);
  }

  // Диагностический лог RAW-пакетов с любой notify/indicate-характеристики.
  // Печатает: порядковый номер пакета с этой характеристики, время с
  // миллисекундами (чтобы сопоставлять с реальными действиями — тревога,
  // вскрытие и т.п.), сами байты в hex и — самое важное — то, что именно
  // изменилось по сравнению с ПРЕДЫДУЩИМ пакетом с этой же характеристики.
  // Это позволяет отличить "пакет одинаков всегда" (скорее всего heartbeat,
  // не связанный с событием) от "поменялись байты N и M" (в них, скорее
  // всего, и зашит код события/ID извещателя).
  void _logRawPacket(String key, List<int> data) {
    final seq = (_rawPacketSeq[key] ?? 0) + 1;
    _rawPacketSeq[key] = seq;

    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';

    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    final prev = _lastRawPacket[key];
    String diff;
    if (prev == null) {
      diff = 'первый пакет с этой характеристики';
    } else if (prev.length != data.length) {
      diff = 'длина изменилась: ${prev.length} → ${data.length} байт';
    } else {
      final changes = <String>[];
      for (int i = 0; i < data.length; i++) {
        if (data[i] != prev[i]) {
          changes.add('[$i] '
              '0x${prev[i].toRadixString(16).padLeft(2, '0')} → '
              '0x${data[i].toRadixString(16).padLeft(2, '0')}');
        }
      }
      diff = changes.isEmpty
          ? 'без изменений относительно предыдущего пакета'
          : 'изменились байты: ${changes.join(', ')}';
    }
    _lastRawPacket[key] = List<int>.from(data);

    debugPrint('📦 RAW [$key] #$seq @ $ts (${data.length} байт): $hex');
    debugPrint('    Δ $diff');
  }

  // Сканирование концентраторов
  Future<void> startScanning() async {
    try {
      if (_isScanning) return;

      _discoveredHubs.clear();
      _isScanning = true;
      notifyListeners();

      debugPrint('▶️ Сканирование (без фильтров, 15 сек)...');

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final deviceName = scanResultName(result);

          debugPrint('BLE: "$deviceName" rssi=${result.rssi}');

          // Идентифицируем концентратор только по имени из списка
          // TARGET_DEVICE_NAMES — заранее известный SERVICE_UUID для этого
          // больше не используется.
          final bool isOurHub = _isTargetName(deviceName);

          if (isOurHub &&
              !_discoveredHubs
                  .any((d) => d.remoteId == result.device.remoteId)) {
            _discoveredHubs.add(result.device);
            debugPrint(
                '✅ НАЙДЕН КОНЦЕНТРАТОР: "$deviceName" (${result.device.remoteId})');
            notifyListeners();

            stopScanning();
            connectToHub(result.device);
          }
        }
      });

      FlutterBluePlus.isScanning.where((val) => val == false).first.then((_) {
        debugPrint(
            '⏹️ Сканирование завершено, найдено: ${_discoveredHubs.length}');
        _isScanning = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('❌ Ошибка: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScanning() async {
    try {
      if (!_isScanning) {
        debugPrint('Сканирование не активно');
        return;
      }

      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _isScanning = false;
      notifyListeners();
      debugPrint('⏹️ Сканирование остановлено вручную');
    } catch (e) {
      debugPrint('Ошибка остановки сканирования: $e');
    }
  }

  // Подключение к концентратору
  //// В классе ReceiverProvider

  Future<void> connectToHub(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      debugPrint('🔄 Подключение к ${device.platformName}...');

      _isConnected = false;
      notifyListeners();

      await device.connect(autoConnect: false, timeout: timeout);
      _connectedHub = device;

      debugPrint('✅ Подключено, ищем сервисы...');

      List<BluetoothService> services = await device.discoverServices();
      debugPrint('📋 Найдено сервисов: ${services.length}');

      // Сбрасываем характеристики
      _eventsChar = null;
      _commandChar = null;

// Ищем нужные характеристики во всех сервисах подряд.
      // UUID самого сервиса и характеристик у BT485_EE2D (и вообще у любого
      // концентратора из TARGET_DEVICE_NAMES) не документирован и может
      // отличаться от прошивки к прошивке, поэтому НЕ сравниваем
      // serviceUuid/charUuid извещателей и событий с жёстко заданными
      // значениями — просто просматриваем характеристики каждого найденного
      // сервиса, независимо от его UUID, и определяем, наш ли это протокол,
      // по содержимому самого пакета (см. ниже).
      for (var service in services) {
        String serviceUuid = service.uuid.toString().toUpperCase();
        debugPrint('Сервис: $serviceUuid');

        for (var characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toUpperCase();
          debugPrint('  Характеристика: $charUuid'
              ' (notify=${characteristic.properties.notify},'
              ' indicate=${characteristic.properties.indicate})');

          // Подписываемся на КАЖДУЮ характеристику, поддерживающую
          // notify/indicate, независимо от её UUID — заранее известного
          // "правильного" UUID для извещателей/событий нет (он отличается
          // от устройства к устройству), поэтому единственный надёжный
          // способ понять, что перед нами наш протокол, — проверить сам
          // пакет: 6 байт, канал 0x22, резервный байт 0x33 (см.
          // _validatePacket). Если пакет валиден — обрабатываем его как
          // событие/инициализацию извещателя, независимо от того, на какой
          // именно характеристике он пришёл. Заодно продолжаем печатать
          // необработанные байты в терминал — это помогает разобрать
          // протокол устройств, для которых формат ещё не подтверждён.
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            try {
              await characteristic.setNotifyValue(true);
              final rawKey = '$serviceUuid/$charUuid';
              characteristic.lastValueStream.listen((data) {
                _logRawPacket(rawKey, data);
                if (_validatePacket(data)) {
                  // HUB может прислать пакет длиннее 6 байт — по протоколу
                  // разбираются только первые 6, остальное отбрасывается.
                  final pkt = data.length > 6 ? data.sublist(0, 6) : data;
                  _eventsChar ??= characteristic;
                  _handleEventData(pkt);
                }
              });
            } catch (e) {
              debugPrint('    ⚠️ Не удалось включить notify для $charUuid: $e');
            }
          }

          // Характеристику команд (запись "GET_DETECTORS" и т.п.) по
          // содержимому не определить — она write-only и сама ничего не
          // присылает, поэтому для неё сравнение по UUID пока оставляем.
          // Если он не совпадёт (как сейчас на BT485_EE2D), команда на
          // устройство просто не отправляется — на приём и разбор пакетов
          // извещателей/событий выше это не влияет.
          if (charUuid.contains("E3A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C8")) {
            _commandChar = characteristic;
            debugPrint('    ✅ ХАРАКТЕРИСТИКА КОМАНД НАЙДЕНА');
          }
        }
      }

      // Характеристика команд определяется по UUID сразу; характеристика
      // извещателей/событий подтверждается только когда придёт первый
      // валидный пакет (см. цикл выше) — сразу после discoverServices() он
      // обычно ещё не получен, поэтому это нормальная промежуточная
      // ситуация, а не ошибка подключения.
      if (_eventsChar == null)
        debugPrint(
            'ℹ️ Пока не получено ни одного валидного пакета извещателей/событий');
      if (_commandChar == null)
        debugPrint(
            'ℹ️ Характеристика команд не найдена (протокол ещё не подключён)');

      _isConnected = true;

      // При каждом новом подключении к концентратору сбрасываем ранее
      // известный список извещателей — пока нет отдельного сервиса
      // добавления/программирования извещателей, актуальный список будет
      // формироваться заново на этом устройстве.
      _detectors.clear();
      await _db.clearDetectors();

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.connected,
        detectorId: 'system',
        detectorName: 'Система',
        description: 'Подключено к концентратору ${device.platformName}',
      ));

      // Запрашиваем список извещателей (если устройство поддерживает
      // соответствующую характеристику команд)
      if (_commandChar != null) {
        debugPrint('📡 Запрос списка извещателей...');
        await _commandChar!.write("GET_DETECTORS".codeUnits);
      }

      notifyListeners();
      debugPrint('✅ Подключение завершено');
    } catch (e) {
      debugPrint('❌ Ошибка подключения: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // ========== ВЫБОР ОСНОВНОГО УСТРОЙСТВА (экран настроек) ==========
  // Отдельный, независимый от startScanning() поиск: находит все
  // устройства из TARGET_DEVICE_NAMES и просто собирает их в список, НЕ
  // подключаясь автоматически — пользователь сам выбирает нужное на
  // экране настроек.

  bool _isPairingScan = false;
  final List<ScanResult> _pairingResults = [];

  bool get isPairingScan => _isPairingScan;
  List<ScanResult> get pairingResults => List.unmodifiable(_pairingResults);

  Future<void> startPairingScan(
      {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      if (_isPairingScan) return;

      final granted = await requestPermissions();
      debugPrint(
          'Разрешения на Bluetooth/геолокацию: ${granted ? "выданы" : "НЕ выданы"}');
      if (!granted) {
        debugPrint(
            '❌ Без разрешений сканирование не найдёт ни одного устройства');
      }

      _pairingResults.clear();
      _isPairingScan = true;
      notifyListeners();

      debugPrint(
          '▶️ Поиск устройств для выбора основного (${timeout.inSeconds} сек)...');

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      _pairingScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = scanResultName(result);

          // Логируем ВСЕ найденные устройства (не только совпадения) —
          // это позволяет посмотреть в консоли, под каким именно именем
          // рекламируется устройство, если оно не подхватывается автоматически.
          debugPrint('BLE (поиск основного): "$name" rssi=${result.rssi} '
              'id=${result.device.remoteId}');

          if (_isTargetName(name) &&
              !_pairingResults
                  .any((r) => r.device.remoteId == result.device.remoteId)) {
            _pairingResults.add(result);
            debugPrint(
                '🔎 Найдено для выбора: "$name" (${result.device.remoteId})');
            notifyListeners();
          }
        }
      });

      FlutterBluePlus.isScanning.where((v) => v == false).first.then((_) {
        _isPairingScan = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('❌ Ошибка поиска устройств: $e');
      _isPairingScan = false;
      notifyListeners();
    }
  }

  Future<void> stopPairingScan() async {
    try {
      if (!_isPairingScan) return;
      await FlutterBluePlus.stopScan();
      await _pairingScanSubscription?.cancel();
      _isPairingScan = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка остановки поиска: $e');
    }
  }

  // Подключиться к устройству, выбранному пользователем из pairingResults,
  // и — если подключение удалось — сообщить его идентификатор и имя через
  // onSaved (обычно это SettingsProvider.setPrimaryDevice), чтобы оно было
  // записано как основное устройство и найдено автоматически при
  // следующем запуске приложения.
  Future<bool> connectAsPrimaryDevice(
    ScanResult result,
    void Function(String remoteId, String name) onSaved,
  ) async {
    await stopPairingScan();
    final name = scanResultName(result);
    await connectToHub(result.device);

    if (_isConnected) {
      onSaved(result.device.remoteId.toString(), name);
      debugPrint(
          '⭐ "$name" (${result.device.remoteId}) сохранён как основное устройство');
      return true;
    }
    return false;
  }

  // ========== АВТОПОДКЛЮЧЕНИЕ К СОХРАНЁННОМУ УСТРОЙСТВУ ==========
  // Вызывается один раз при старте приложения (см. main_screen.dart).
  // Если основное устройство ранее было выбрано на экране настроек —
  // пытаемся подключиться к нему напрямую по идентификатору, а если это
  // не удалось (например, Bluetooth ещё не готов) — ищем его в эфире по
  // идентификатору/имени и подключаемся, как только оно появится.
  Future<void> autoConnectToSaved(String? remoteId, String? name) async {
    if (remoteId == null || remoteId.isEmpty) {
      debugPrint(
          'ℹ️ Основное устройство не выбрано — авто-подключение пропущено');
      return;
    }
    if (_isConnected) return;

    debugPrint(
        '🔁 Пробуем подключиться к сохранённому устройству "$name" ($remoteId)...');

    try {
      final device = BluetoothDevice.fromId(remoteId);
      await connectToHub(device, timeout: const Duration(seconds: 8));
      if (_isConnected) {
        debugPrint('✅ Подключились к сохранённому устройству напрямую');
        return;
      }
    } catch (e) {
      debugPrint('Прямое подключение к сохранённому устройству не удалось: $e');
    }

    await _scanAndConnectSaved(remoteId: remoteId, name: name);
  }

  Future<void> _scanAndConnectSaved({
    required String remoteId,
    String? name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      if (_isScanning || _isConnected) return;

      _discoveredHubs.clear();
      _isScanning = true;
      notifyListeners();

      debugPrint('▶️ Ищем сохранённое устройство в эфире...');

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final deviceName = scanResultName(result);
          debugPrint(
              'BLE (поиск сохранённого): "$deviceName" rssi=${result.rssi} '
              'id=${result.device.remoteId}');

          final matches = result.device.remoteId.toString() == remoteId ||
              (name != null &&
                  name.isNotEmpty &&
                  deviceName.trim().toLowerCase() == name.trim().toLowerCase());

          if (matches) {
            debugPrint('✅ Сохранённое устройство найдено: "$deviceName"');
            stopScanning();
            connectToHub(result.device);
            return;
          }
        }
      });

      FlutterBluePlus.isScanning.where((v) => v == false).first.then((_) {
        _isScanning = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('❌ Ошибка авто-поиска сохранённого устройства: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  // ========== ПАРСИНГ ПАКЕТА ПО ПЕРВЫМ 6 БАЙТАМ ==========
  // HUB может передать пакет любой длины — анализируются только первые
  // 6 байт по уже известному протоколу, остальное (если есть) игнорируется:
  // [0] ID_HI  [1] ID_LO  [2] CHANNEL(0x22)
  // [3] eventCode  [4] RESERVED(0x33)  [5] nodeType

  static const int _channel = 0xaa;
  static const int _reserved = 0x33;

  bool _validatePacket(List<int> pkt) {
    if (pkt.length < 6) {
      debugPrint('Неверная длина пакета: ${pkt.length} (нужно минимум 6 байт)');
      return false;
    }
    if (pkt[2] != _channel) {
      debugPrint('Неверный канал: 0x${pkt[2].toRadixString(16)}');
      return false;
    }
    if (pkt[4] != _reserved) {
      debugPrint('Неверный резервный байт: 0x${pkt[4].toRadixString(16)}');
      return false;
    }
    return true;
  }

  EventType _eventCodeToEventType(int code) {
    switch (code) {
      case 0x55:
        return EventType.alarm;
      case 0xA8:
        return EventType.lowBattery;
      case 0x58:
        return EventType.tamper;
      case 0xA9:
        return EventType.connected;
      case 0xAB:
        return EventType.disconnected;
      case 0xAA:
        return EventType.restored;
      case 0xAC:
        return EventType.restored;
      case 0xA4:
        return EventType.restored;
      default:
        return EventType.restored;
    }
  }

  String _eventDescription(int evtCode, String name) {
    switch (evtCode) {
      case 0x55:
        return 'ТРЕВОГА: $name';
      case 0xAA:
        return 'Контрольный сигнал: $name';
      case 0xA8:
        return 'Разряд батареи: $name';
      case 0x58:
        return 'Вскрытие корпуса: $name';
      case 0xA9:
        return 'Включение: $name';
      case 0xAB:
        return 'Выключение: $name';
      case 0xAC:
        return 'Напряжение: $name';
      case 0xA4:
        return 'Режим чувствительности: $name';
      default:
        return 'Событие 0x${evtCode.toRadixString(16).toUpperCase()}: $name';
    }
  }

  // Отключение от концентратора
  Future<void> disconnectFromHub() async {
    try {
      _audio.stop();
      await _connectedHub?.disconnect();

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.disconnected,
        detectorId: 'system',
        detectorName: 'Система',
        description: 'Отключено от концентратора',
      ));

      _isConnected = false;
      _connectedHub = null;
      _eventsChar = null;
      _commandChar = null;

      // Отмечаем все извещатели как офлайн
      for (var detector in _detectors) {
        if (detector.status != DetectorStatus.offline) {
          detector.status = DetectorStatus.offline;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка отключения: $e');
    }
  }

  // Запрос списка извещателей
  Future<void> _requestDetectorsList() async {
    if (_commandChar != null && _isConnected) {
      await _commandChar!.write('GET_DETECTORS'.codeUnits);
    }
  }

  void _handleEventData(List<int> data) {
    if (!_validatePacket(data)) return;

    final evtCode = data[3];
    final nodeType = data[5];
    final evtType = _eventCodeToEventType(evtCode);
    final detId = DetectorModel.idFromPacket(data);
    final detName = DetectorModel.nameFromNodeType(nodeType);

    debugPrint(
        'Событие $detId ($detName) код 0x${evtCode.toRadixString(16).toUpperCase()} → $evtType');

    _addEvent(EventModel(
      timestamp: DateTime.now(),
      type: evtType,
      detectorId: detId,
      detectorName: '$detName [$detId]',
      description: _eventDescription(evtCode, '$detName [$detId]'),
    ));

    // Обновляем статус датчика в списке (или инициализируем новый, если
    // пакет события — первый когда-либо полученный от этого извещателя:
    // характеристика извещателей на устройстве может не использоваться, и
    // тогда единственный способ узнать о новом извещателе — это пакет
    // события, включая самый первый пришедший как тревога).
    final idx = _detectors.indexWhere((d) => d.id == detId);

    // Фиксируем момент начала тревоги и ставим красную рамку —
    // одинаково и для уже известных, и для новых извещателей.
    if (evtCode == 0x55) {
      _alarmStartTimes[detId] = DateTime.now();
      _alarmBorderActive[detId] = true;
      if (_soundEnabled) _audio.playAlarm();
    } else if (evtCode == 0xA8 || evtCode == 0x58) {
      if (_soundEnabled) _audio.playWarning();
    }

    if (idx >= 0) {
      final newStatus = DetectorModel.statusFromEventCode(evtCode);

      _detectors[idx] = _detectors[idx].copyWith(
        status: newStatus,
        lastSeen: DateTime.now(),
        lastEventCode: evtCode,
        alarmCount: evtCode == 0x55
            ? _detectors[idx].alarmCount + 1
            : _detectors[idx].alarmCount,
      );
      _db.saveDetector(_detectors[idx]);
    } else {
      // Новый извещатель: инициализируем его прямо по пакету события и
      // сразу добавляем в список (главный экран) и в базу данных.
      final newDetector = DetectorModel.fromPacket(data)
        ..alarmCount = evtCode == 0x55 ? 1 : 0;

      _detectors.add(newDetector);
      _db.saveDetector(newDetector);

      debugPrint('🆕 Новый извещатель инициализирован: $detId ($detName)');
    }

    notifyListeners();
  }

  // Добавить событие
  void _addEvent(EventModel event) {
    _events.insert(0, event);
    _db.saveEvent(event);

    if (_events.length > 500) {
      _events = _events.take(500).toList();
    }

    notifyListeners();
  }

  // Отметить события как прочитанные
  Future<void> markEventsAsRead() async {
    for (var event in _events) {
      event.isRead = true;
    }
    await _db.markEventsAsRead();
    notifyListeners();
  }

  // Отключить тревогу конкретного извещателя
  Future<void> disarmDetectorAlarm(String detectorId) async {
    final idx = _detectors.indexWhere((d) => d.id == detectorId);
    if (idx < 0) return;

    _alarmBorderActive.remove(detectorId);
    _alarmStartTimes.remove(detectorId);
    // Останавливаем сирену если больше нет активных тревог
    if (_alarmBorderActive.isEmpty) _audio.stop();

    if (_detectors[idx].status == DetectorStatus.alarm ||
        _detectors[idx].status == DetectorStatus.tamper) {
      _detectors[idx] = _detectors[idx].copyWith(status: DetectorStatus.normal);
      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.restored,
        detectorId: detectorId,
        detectorName: _detectors[idx].name,
        description: 'Тревога сброшена: ${_detectors[idx].name} [$detectorId]',
      ));
    }

    notifyListeners();
  }

  // Отключить все тревоги
  Future<void> disarmAllAlarms() async {
    int count = 0;
    _alarmBorderActive.clear();
    _alarmStartTimes.clear();
    _audio.stop();

    for (int i = 0; i < _detectors.length; i++) {
      if (_detectors[i].status == DetectorStatus.alarm ||
          _detectors[i].status == DetectorStatus.tamper) {
        _detectors[i] = _detectors[i].copyWith(status: DetectorStatus.normal);
        count++;
      }
    }

    if (count > 0) {
      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.systemDisarmed,
        detectorId: 'system',
        detectorName: 'Система',
        description: 'Отключены все тревоги ($count)',
      ));
      notifyListeners();
    }
  }

  // Поставить извещатель на охрану
  Future<void> armDetector(String detectorId) async {
    var detector = _detectors.firstWhere((d) => d.id == detectorId);

    if (!detector.isArmed) {
      detector.isArmed = true;
      await _db.updateDetectorArmed(detectorId, true);

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.armed,
        detectorId: detectorId,
        detectorName: detector.name,
        description: '${detector.name} поставлен на охрану',
      ));

      notifyListeners();
    }
  }

  // Снять извещатель с охраны
  Future<void> disarmDetector(String detectorId) async {
    var detector = _detectors.firstWhere((d) => d.id == detectorId);

    if (detector.isArmed) {
      detector.isArmed = false;
      await _db.updateDetectorArmed(detectorId, false);

      // Если была тревога, сбрасываем
      if (detector.status == DetectorStatus.alarm) {
        detector.status = DetectorStatus.normal;
      }

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.disarmed,
        detectorId: detectorId,
        detectorName: detector.name,
        description: '${detector.name} снят с охраны',
      ));

      notifyListeners();
    }
  }

  // Поставить зону на охрану
  Future<void> armZone(int zone) async {
    var zoneDetectors = _detectors.where((d) => d.zone == zone);

    for (var detector in zoneDetectors) {
      if (!detector.isArmed) {
        detector.isArmed = true;
      }
    }

    await _db.updateZoneArmed(zone, true);

    _addEvent(EventModel(
      timestamp: DateTime.now(),
      type: EventType.zoneArmed,
      detectorId: 'zone_$zone',
      detectorName: zoneName(zone),
      description:
          '${zoneName(zone)} поставлена на охрану (${zoneDetectors.length} извещателей)',
    ));

    notifyListeners();
  }

  // Снять зону с охраны
  Future<void> disarmZone(int zone) async {
    var zoneDetectors = _detectors.where((d) => d.zone == zone);

    for (var detector in zoneDetectors) {
      if (detector.isArmed) {
        detector.isArmed = false;
      }
      // Сбрасываем тревоги в зоне
      if (detector.status == DetectorStatus.alarm) {
        detector.status = DetectorStatus.normal;
      }
    }

    await _db.updateZoneArmed(zone, false);

    _addEvent(EventModel(
      timestamp: DateTime.now(),
      type: EventType.zoneDisarmed,
      detectorId: 'zone_$zone',
      detectorName: zoneName(zone),
      description:
          '${zoneName(zone)} снята с охраны (${zoneDetectors.length} извещателей)',
    ));

    notifyListeners();
  }

  // Поставить все на охрану
  Future<void> armAll() async {
    int count = 0;

    for (var detector in _detectors) {
      if (!detector.isArmed) {
        detector.isArmed = true;
        count++;
      }
    }

    var zones = await _db.getZones();
    for (var zone in zones) {
      await _db.updateZoneArmed(zone['id'], true);
    }

    _addEvent(EventModel(
      timestamp: DateTime.now(),
      type: EventType.systemArmed,
      detectorId: 'system',
      detectorName: 'Система',
      description: 'Система поставлена на охрану ($count извещателей)',
    ));

    notifyListeners();
  }

  // Снять все с охраны
  Future<void> disarmAll() async {
    int count = 0;

    for (var detector in _detectors) {
      if (detector.isArmed) {
        detector.isArmed = false;
        count++;
      }
      // Сбрасываем все тревоги
      if (detector.status == DetectorStatus.alarm) {
        detector.status = DetectorStatus.normal;
      }
    }

    var zones = await _db.getZones();
    for (var zone in zones) {
      await _db.updateZoneArmed(zone['id'], false);
    }

    _addEvent(EventModel(
      timestamp: DateTime.now(),
      type: EventType.systemDisarmed,
      detectorId: 'system',
      detectorName: 'Система',
      description: 'Система снята с охраны ($count извещателей)',
    ));

    notifyListeners();
  }

  // Экспорт событий в CSV
  String exportEventsToCsv({
    DateTime? startDate,
    DateTime? endDate,
    List<EventType>? types,
    String? detectorId,
  }) {
    var eventsToExport = List<EventModel>.from(_events);

    // Фильтрация
    if (startDate != null) {
      eventsToExport =
          eventsToExport.where((e) => e.timestamp.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      eventsToExport =
          eventsToExport.where((e) => e.timestamp.isBefore(endDate)).toList();
    }
    if (types != null && types.isNotEmpty) {
      eventsToExport =
          eventsToExport.where((e) => types.contains(e.type)).toList();
    }
    if (detectorId != null) {
      eventsToExport =
          eventsToExport.where((e) => e.detectorId == detectorId).toList();
    }

    String csv = 'Дата,Время,Тип,Извещатель,Описание\n';

    for (var event in eventsToExport) {
      csv +=
          '${event.timestamp.toLocal().year}-${event.timestamp.toLocal().month.toString().padLeft(2, '0')}-${event.timestamp.toLocal().day.toString().padLeft(2, '0')},'
          '${event.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${event.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${event.timestamp.toLocal().second.toString().padLeft(2, '0')},'
          '${_getEventTypeName(event.type)},'
          '${event.detectorName},'
          '${event.description}\n';
    }

    return csv;
  }

  String _getEventTypeName(EventType type) {
    switch (type) {
      case EventType.alarm:
        return 'ТРЕВОГА';
      case EventType.tamper:
        return 'ВСКРЫТИЕ';
      case EventType.lowBattery:
        return 'РАЗРЯД';
      case EventType.restored:
        return 'ВОССТАНОВЛЕНИЕ';
      case EventType.connected:
        return 'ПОДКЛЮЧЕНИЕ';
      case EventType.disconnected:
        return 'ОТКЛЮЧЕНИЕ';
      case EventType.armed:
        return 'ОХРАНА';
      case EventType.disarmed:
        return 'СНЯТО';
      case EventType.systemArmed:
        return 'ОХРАНА ВСЕ';
      case EventType.systemDisarmed:
        return 'СНЯТО ВСЕ';
      case EventType.zoneArmed:
        return 'ОХРАНА ЗОНЫ';
      case EventType.zoneDisarmed:
        return 'СНЯТО ЗОНЫ';
    }
  }

  // Получить статистику для графиков
  Map<String, int> getEventsStats({int days = 7}) {
    Map<String, int> stats = {};
    var now = DateTime.now();

    for (int i = 0; i < days; i++) {
      var date = now.subtract(Duration(days: i));
      var dateStr = '${date.day}.${date.month}';
      stats[dateStr] = 0;
    }

    for (var event in _events) {
      var daysAgo = now.difference(event.timestamp).inDays;
      if (daysAgo < days) {
        var dateStr = '${event.timestamp.day}.${event.timestamp.month}';
        stats[dateStr] = (stats[dateStr] ?? 0) + 1;
      }
    }

    return stats;
  }

  // Очистить все данные
  Future<void> clearAllData() async {
    _detectors.clear();
    _events.clear();
    await _db.clearAllData();
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pairingScanSubscription?.cancel();
    _connectionMonitorTimer?.cancel();
    _connectedHub?.disconnect();
    _audio.dispose();
    super.dispose();
  }
}
