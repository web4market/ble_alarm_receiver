import 'package:flutter/material.dart';

enum DetectorType { loraL50, loraL60, loraL70, loraV10 }

enum DetectorStatus { normal, alarm, tamper, lowBattery, offline, off }

class DetectorModel {
  // ID — двухбайтный порядковый номер из пакета (байты 0-1), строка "0001".."0008"
  final String id;
  final String name;     // название модели: L50RA, L60RA, L70RA, V10RA
  final DetectorType type;
  DetectorStatus status;
  DateTime lastSeen;
  int zone;
  String place;   // конкретное место в зоне: окно, калитка, дверь и т.д.
  bool isActive;
  int alarmCount;
  bool isArmed;
  int nodeType;          // сырой байт типа (байт 5): 0x71..0x74
  int lastEventCode;     // последний код события (байт 3)

  DetectorModel({
    required this.id,
    required this.name,
    required this.type,
    this.status = DetectorStatus.normal,
    DateTime? lastSeen,
    this.zone = 1,
    this.place = '',
    this.isActive = true,
    this.alarmCount = 0,
    this.isArmed = true,
    required this.nodeType,
    this.lastEventCode = 0xAA,
  }) : lastSeen = lastSeen ?? DateTime.now();

  // ── Конвертеры ──────────────────────────────────────────────────────────────

  /// ID из байтов 0-1 пакета. Формат: "0001"
  static String idFromPacket(List<int> pkt) {
    final val = (pkt[0] << 8) | pkt[1];
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Название модели по типу (байт 5)
  static String nameFromNodeType(int nodeType) {
    switch (nodeType) {
      case 0x71: return 'L50RA';
      case 0x72: return 'L60RA';
      case 0x73: return 'L70RA';
      case 0x74: return 'V10RA';
      default:   return 'Узел ${nodeType.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    }
  }

  static DetectorType typeFromNodeType(int nodeType) {
    switch (nodeType) {
      case 0x71: return DetectorType.loraL50;
      case 0x72: return DetectorType.loraL60;
      case 0x73: return DetectorType.loraL70;
      case 0x74: return DetectorType.loraV10;
      default:   return DetectorType.loraL50;
    }
  }

  /// Статус из кода события (байт 3)
  static DetectorStatus statusFromEventCode(int code) {
    switch (code) {
      case 0x55: return DetectorStatus.alarm;
      case 0xA8: return DetectorStatus.lowBattery;
      case 0x58: return DetectorStatus.tamper;
      case 0xAB: return DetectorStatus.off;
      case 0xA9:
      case 0xAA:
      case 0xAC:
      case 0xA4: return DetectorStatus.normal;
      default:   return DetectorStatus.normal;
    }
  }

  /// Создание из 6-байтного пакета:
  /// [0] ID_HI  [1] ID_LO  [2] CHANNEL(0x22)
  /// [3] eventCode  [4] RESERVED(0x33)  [5] nodeType
  factory DetectorModel.fromPacket(List<int> pkt) {
    final nt  = pkt[5];
    final evt = pkt[3];
    return DetectorModel(
      id:            idFromPacket(pkt),
      name:          nameFromNodeType(nt),
      type:          typeFromNodeType(nt),
      nodeType:      nt,
      status:        statusFromEventCode(evt),
      lastEventCode: evt,
    );
  }

  // ── copyWith ─────────────────────────────────────────────────────────────────

  DetectorModel copyWith({
    DetectorStatus? status,
    DateTime? lastSeen,
    int? zone,
    String? place,
    bool? isActive,
    int? alarmCount,
    bool? isArmed,
    int? lastEventCode,
  }) {
    return DetectorModel(
      id:            id,
      name:          name,
      type:          type,
      nodeType:      nodeType,
      status:        status        ?? this.status,
      lastSeen:      lastSeen      ?? this.lastSeen,
      zone:          zone          ?? this.zone,
      place:         place         ?? this.place,
      isActive:      isActive      ?? this.isActive,
      alarmCount:    alarmCount    ?? this.alarmCount,
      isArmed:       isArmed       ?? this.isArmed,
      lastEventCode: lastEventCode ?? this.lastEventCode,
    );
  }

  // ── Сериализация ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'type':          type.index,
    'status':        status.index,
    'lastSeen':      lastSeen.toIso8601String(),
    'zone':          zone,
    'place':         place,
    'isActive':      isActive ? 1 : 0,
    'alarmCount':    alarmCount,
    'isArmed':       isArmed ? 1 : 0,
    'nodeType':      nodeType,
    'lastEventCode': lastEventCode,
  };

  factory DetectorModel.fromJson(Map<String, dynamic> json) {
    return DetectorModel(
      id:            json['id'] ?? '0000',
      name:          json['name'] ?? 'Неизвестно',
      type:          DetectorType.values[json['type'] ?? 0],
      status:        DetectorStatus.values[json['status'] ?? 0],
      lastSeen:      DateTime.parse(json['lastSeen']),
      zone:          json['zone'] ?? 1,
      place:         json['place'] ?? '',
      isActive:      json['isActive'] == 1,
      alarmCount:    json['alarmCount'] ?? 0,
      isArmed:       json['isArmed'] == 1,
      nodeType:      json['nodeType'] ?? 0,
      lastEventCode: json['lastEventCode'] ?? 0xAA,
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  IconData get icon {
    switch (type) {
      case DetectorType.loraL50: return Icons.sensors;
      case DetectorType.loraL60: return Icons.sensors;
      case DetectorType.loraL70: return Icons.show_chart;
      case DetectorType.loraV10: return Icons.leak_add;
    }
  }

  Color get statusColor {
    if (!isArmed) return Colors.grey;
    switch (status) {
      case DetectorStatus.normal:    return Colors.green;
      case DetectorStatus.alarm:     return Colors.red;
      case DetectorStatus.tamper:    return Colors.purple;
      case DetectorStatus.lowBattery:return Colors.orange;
      case DetectorStatus.offline:   return Colors.grey;
      case DetectorStatus.off:       return Colors.blueGrey;
    }
  }

  String get statusText {
    if (!isArmed) return 'Снято';
    switch (status) {
      case DetectorStatus.normal:    return 'Норма';
      case DetectorStatus.alarm:     return 'ТРЕВОГА';
      case DetectorStatus.tamper:    return 'ВСКРЫТИЕ';
      case DetectorStatus.lowBattery:return 'Разряд';
      case DetectorStatus.offline:   return 'Нет связи';
      case DetectorStatus.off:       return 'Выкл';
    }
  }

  String get lastEventText {
    switch (lastEventCode) {
      case 0x55: return 'Тревога';
      case 0xA9: return 'Включение';
      case 0xAB: return 'Выключение';
      case 0xA8: return 'Разряд батареи';
      case 0xAC: return 'Напряжение';
      case 0xAA: return 'Контроль';
      case 0xA4: return 'Чувствительность';
      case 0x58: return 'Вскрытие';
      default:   return '0x${lastEventCode.toRadixString(16).toUpperCase()}';
    }
  }

  @override
  String toString() => '$name [$id] - $statusText';
}
