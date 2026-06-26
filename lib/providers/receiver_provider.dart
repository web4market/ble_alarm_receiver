import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detector_model.dart';
import '../models/event_model.dart';
import '../services/database_service.dart';

class ReceiverProvider extends ChangeNotifier {
  bool _isScanning = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedHub;
  List<BluetoothDevice> _discoveredHubs = [];
  List<DetectorModel> _detectors = [];
  List<EventModel> _events = [];
  final DatabaseService _db = DatabaseService();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  Timer? _connectionMonitorTimer;

  // UUID для BLE (должны совпадать с концентратором)
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
    "Security Hub"
  ];

  BluetoothCharacteristic? _detectorsChar;
  BluetoothCharacteristic? _eventsChar;
  BluetoothCharacteristic? _commandChar;

  // Геттеры
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedHub => _connectedHub;
  List<BluetoothDevice> get discoveredHubs => _discoveredHubs;
  List<DetectorModel> get detectors => _detectors;
  List<EventModel> get events => _events;

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

  // Сканирование концентраторов
  Future<void> startScanning() async {
    try {
      if (_isScanning) return;

      _discoveredHubs.clear();
      _isScanning = true;
      notifyListeners();

      debugPrint('▶️ Сканирование (без фильтров)...');

      // Простое сканирование без параметров
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Фильтруем только устройства с нашим именем или UUID сервиса
          // bool isOurHub = false;
          bool isOurHub =
              TARGET_DEVICE_NAMES.contains(result.device.platformName);

          // Проверка по имени устройства
          if (result.device.platformName == "BLE Alarm Hub") {
            isOurHub = true;
          }

          // Проверка по UUID сервиса (если имя по какой-то причине не совпадает)
          if (result.advertisementData.serviceUuids
              .contains(Guid(SERVICE_UUID))) {
            isOurHub = true;
          }

          // Добавляем только наше устройство
          if (isOurHub &&
              !_discoveredHubs
                  .any((d) => d.remoteId == result.device.remoteId)) {
            _discoveredHubs.add(result.device);
            debugPrint('📡 НАЙДЕН КОНЦЕНТРАТОР: ${result.device.platformName}');
            notifyListeners();

            // Опционально: автоматически останавливаем сканирование после нахождения
            stopScanning();

            // Автоматически подключаемся
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

  Future<void> connectToHub(BluetoothDevice device) async {
    try {
      debugPrint('🔄 Подключение к ${device.platformName}...');

      _isConnected = false;
      notifyListeners();

      await device.connect(autoConnect: false);
      _connectedHub = device;

      debugPrint('✅ Подключено, ищем сервисы...');

      List<BluetoothService> services = await device.discoverServices();
      debugPrint('📋 Найдено сервисов: ${services.length}');

      // Сбрасываем характеристики
      _detectorsChar = null;
      _eventsChar = null;
      _commandChar = null;

// Ищем нужные сервисы и характеристики
      for (var service in services) {
        String serviceUuid = service.uuid.toString().toUpperCase();
        debugPrint('Сервис: $serviceUuid');

        // ПРОСТОЕ СРАВНЕНИЕ - ищем вхождение ключевой части UUID
        if (serviceUuid.contains("E0A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C5")) {
          debugPrint('✅ Найден нужный сервис!');

          for (var characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toUpperCase();
            debugPrint('  Характеристика: $charUuid');

            // Простое сравнение по ключевой части
            if (charUuid.contains("E1A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C6")) {
              _detectorsChar = characteristic;
              await _detectorsChar!.setNotifyValue(true);
              _detectorsChar!.lastValueStream.listen(_handleDetectorsData);
              debugPrint('    ✅ ХАРАКТЕРИСТИКА ИЗВЕЩАТЕЛЕЙ НАЙДЕНА');
            } else if (charUuid
                .contains("E2A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C7")) {
              _eventsChar = characteristic;
              await _eventsChar!.setNotifyValue(true);
              _eventsChar!.lastValueStream.listen(_handleEventData);
              debugPrint('    ✅ ХАРАКТЕРИСТИКА СОБЫТИЙ НАЙДЕНА');
            } else if (charUuid
                .contains("E3A1B2C3-D4E5-F6A7-B8C9-D0E1F2A3B4C8")) {
              _commandChar = characteristic;
              debugPrint('    ✅ ХАРАКТЕРИСТИКА КОМАНД НАЙДЕНА');
            }
          }
        }
      }

      // Проверяем результаты
      if (_detectorsChar == null)
        debugPrint('❌ Характеристика извещателей не найдена!');
      if (_eventsChar == null)
        debugPrint('❌ Характеристика событий не найдена!');
      if (_commandChar == null)
        debugPrint('❌ Характеристика команд не найдена!');

      _isConnected = true;

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.connected,
        detectorId: 'system',
        detectorName: 'Система',
        description: 'Подключено к концентратору ${device.platformName}',
      ));

      // Запрашиваем список извещателей
      if (_commandChar != null) {
        debugPrint('📡 Запрос списка извещателей...');
        await _commandChar!.write("GET_DETECTORS".codeUnits);
      } else {
        debugPrint(
            '❌ Не могу запросить извещатели: характеристика команд не найдена');
      }

      notifyListeners();
      debugPrint('✅ Подключение завершено');
    } catch (e) {
      debugPrint('❌ Ошибка подключения: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // ========== ПАРСИНГ 16-БАЙТНОГО ПАКЕТА СПЛАВ ==========

  // Проверка CRC: сумма байт 0..14 mod 256
  bool _checkCRC(List<int> pkt) {
    int sum = 0;
    for (int i = 0; i < 15; i++) sum = (sum + pkt[i]) & 0xFF;
    return sum == pkt[15];
  }

  // Перевод даты пакета (байт 13) в DateTime
  DateTime _packetTimestamp(int h, int m, int s, int daysSince2000) {
    final base = DateTime.utc(2000, 1, 1);
    final date = base.add(Duration(days: daysSince2000));
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  // Код события → DetectorStatus
  DetectorStatus _eventCodeToStatus(int code) {
    switch (code) {
      case 0x55: return DetectorStatus.alarm;
      case 0xA8: return DetectorStatus.lowBattery;
      case 0x58: return DetectorStatus.tamper;
      case 0xAB: return DetectorStatus.normal; // выкл
      default:   return DetectorStatus.normal;
    }
  }

  // Код события → EventType
  EventType _eventCodeToEventType(int code) {
    switch (code) {
      case 0x55: return EventType.alarm;
      case 0xA8: return EventType.lowBattery;
      case 0x58: return EventType.tamper;
      case 0xA9: return EventType.connected;
      case 0xAB: return EventType.disconnected;
      case 0xAA: return EventType.restored;
      default:   return EventType.restored;
    }
  }

  void _handleDetectorsData(List<int> data) {
    if (data.length != 16) {
      debugPrint('Неверная длина пакета: ${data.length}');
      return;
    }
    if (!_checkCRC(data)) {
      debugPrint('Ошибка CRC пакета');
      return;
    }

    final nodeId   = DetectorModel.nodeId(data[0], data[1]);
    final evtCode  = data[4];
    final nodeType = data[9];
    final ts       = _packetTimestamp(data[10], data[11], data[12], data[13]);
    final status   = _eventCodeToStatus(evtCode);

    debugPrint('Пакет узла $nodeId код ${evtCode.toRadixString(16)} статус $status');

    final existingIndex = _detectors.indexWhere((d) => d.id == nodeId);
    if (existingIndex >= 0) {
      _detectors[existingIndex] = _detectors[existingIndex].copyWith(
        status: status,
        lastSeen: ts,
        isActive: true,
      );
    } else {
      _detectors.add(DetectorModel(
        id: nodeId,
        name: DetectorModel.nameFromNodeType(nodeType, nodeId),
        type: DetectorModel.typeFromNodeType(nodeType),
        nodeType: nodeType,
        status: status,
        lastSeen: ts,
      ));
    }

    _db.saveDetectors(_detectors);
    notifyListeners();
  }

  // Отключение от концентратора
  Future<void> disconnectFromHub() async {
    try {
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
      _detectorsChar = null;
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
    if (data.length != 16) {
      debugPrint('Неверная длина пакета события: ${data.length}');
      return;
    }
    if (!_checkCRC(data)) {
      debugPrint('Ошибка CRC пакета события');
      return;
    }

    final nodeId   = DetectorModel.nodeId(data[0], data[1]);
    final evtCode  = data[4];
    final nodeType = data[9];
    final ts       = _packetTimestamp(data[10], data[11], data[12], data[13]);
    final evtType  = _eventCodeToEventType(evtCode);
    final status   = _eventCodeToStatus(evtCode);

    final existingDetector = _detectors.firstWhere(
      (d) => d.id == nodeId,
      orElse: () => DetectorModel(
        id: nodeId,
        name: DetectorModel.nameFromNodeType(nodeType, nodeId),
        type: DetectorModel.typeFromNodeType(nodeType),
        nodeType: nodeType,
      ),
    );

    debugPrint('Событие узла $nodeId код ${evtCode.toRadixString(16)} тип $evtType');

    _addEvent(EventModel(
      timestamp: ts,
      type: evtType,
      detectorId: nodeId,
      detectorName: existingDetector.name,
      description: _eventDescription(evtCode, existingDetector.name),
    ));

    // Обновляем статус датчика в списке
    final index = _detectors.indexWhere((d) => d.id == nodeId);
    if (index >= 0) {
      _detectors[index] = _detectors[index].copyWith(
        status: status,
        lastSeen: ts,
        alarmCount: evtCode == 0x55
            ? _detectors[index].alarmCount + 1
            : _detectors[index].alarmCount,
      );
      notifyListeners();
    }
  }

  String _eventDescription(int evtCode, String name) {
    switch (evtCode) {
      case 0x55: return 'ТРЕВОГА: $name';
      case 0xAA: return 'Норма: $name';
      case 0xA8: return 'Разряд батареи: $name';
      case 0x58: return 'Вскрытие корпуса: $name';
      case 0xA9: return 'Включение: $name';
      case 0xAB: return 'Выключение: $name';
      case 0xB9: return 'Система включена';
      case 0xBA: return 'Система выключена';
      default:   return 'Событие ${evtCode.toRadixString(16).toUpperCase()}: $name';
    }
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
    var detector = _detectors.firstWhere((d) => d.id == detectorId);

    if (detector.status == DetectorStatus.alarm ||
        detector.status == DetectorStatus.tamper) {
      detector.status = DetectorStatus.normal;

      _addEvent(EventModel(
        timestamp: DateTime.now(),
        type: EventType.restored,
        detectorId: detectorId,
        detectorName: detector.name,
        description: 'Тревога отключена для ${detector.name}',
      ));

      notifyListeners();
    }
  }

  // Отключить все тревоги
  Future<void> disarmAllAlarms() async {
    int count = 0;

    for (var detector in _detectors) {
      if (detector.status == DetectorStatus.alarm ||
          detector.status == DetectorStatus.tamper) {
        detector.status = DetectorStatus.normal;
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
      detectorName: 'Зона $zone',
      description:
          'Зона $zone поставлена на охрану (${zoneDetectors.length} извещателей)',
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
      detectorName: 'Зона $zone',
      description:
          'Зона $zone снята с охраны (${zoneDetectors.length} извещателей)',
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

  // Обновить извещатели из данных концентратора
  Future<void> updateDetectorsFromHub(List<DetectorModel> newDetectors) async {
    // Обновляем существующие или добавляем новые
    for (var newDetector in newDetectors) {
      var existingIndex = _detectors.indexWhere((d) => d.id == newDetector.id);

      if (existingIndex >= 0) {
        // Сохраняем состояние охраны
        newDetector.isArmed = _detectors[existingIndex].isArmed;
        _detectors[existingIndex] = newDetector;
      } else {
        _detectors.add(newDetector);
      }
    }

    // Отмечаем отсутствующие как неактивные
    for (var detector in _detectors) {
      if (!newDetectors.any((d) => d.id == detector.id)) {
        detector.isActive = false;
        detector.status = DetectorStatus.offline;
      } else {
        detector.isActive = true;
      }
    }

    await _db.saveDetectors(_detectors);
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
    _connectionMonitorTimer?.cancel();
    _connectedHub?.disconnect();
    super.dispose();
  }
}
