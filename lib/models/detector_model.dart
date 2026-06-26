import 'package:flutter/material.dart';

enum DetectorType { vibration, infraredLinear, infraredVolumetric }
enum DetectorStatus { normal, alarm, tamper, lowBattery, offline }

class DetectorModel {
  final String id;       // hex-строка из nodeHi+nodeLo, например "0010"
  final String name;
  final DetectorType type;
  DetectorStatus status;
  int batteryLevel;
  DateTime lastSeen;
  int zone;
  bool isActive;
  int alarmCount;
  bool isArmed;
  int nodeType;          // сырой байт типа узла по спецификации СПЛАВ
  Map<String, dynamic> parameters;

  DetectorModel({
    required this.id,
    required this.name,
    required this.type,
    this.status = DetectorStatus.normal,
    this.batteryLevel = 100,
    DateTime? lastSeen,
    this.zone = 1,
    this.isActive = true,
    this.alarmCount = 0,
    this.isArmed = true,
    this.nodeType = 0,
    this.parameters = const {},
  }) : lastSeen = lastSeen ?? DateTime.now();

  // Формирует строковый ID из двух байт адреса узла
  static String nodeId(int hi, int lo) =>
      hi.toRadixString(16).padLeft(2, '0').toUpperCase() +
      lo.toRadixString(16).padLeft(2, '0').toUpperCase();

  // Имя узла по типу из спецификации СПЛАВ
  static String nameFromNodeType(int nodeType, String id) {
    switch (nodeType) {
      case 0xA9: return 'L50 [$id]';
      case 0xA8: return 'Accel [$id]';
      case 0xA7: return 'L70 [$id]';
      case 0xA6: return 'V10 [$id]';
      case 0xA5: return 'L50multi [$id]';
      case 0xA4: return 'L70multi [$id]';
      case 0xA3: return 'СПЛАВ Alarm [$id]';
      case 0xA2: return 'Lighter [$id]';
      case 0xA1: return 'Реле [$id]';
      case 0xAA: return 'Приёмник RM [$id]';
      case 0xAB: return 'Приёмник 10rele [$id]';
      case 0xAC: return 'Брелок [$id]';
      case 0x55: return 'Ретранслятор [$id]';
      case 0xBA: return 'Датчик газа [$id]';
      case 0xBB: return 'Датчик пожара [$id]';
      case 0xBC: return 'Датчик протечки [$id]';
      case 0xBD: return 'Датчик темп. [$id]';
      case 0xBE: return 'Датчик влажн. [$id]';
      default:   return 'Узел [$id]';
    }
  }

  // DetectorType из байта типа узла
  static DetectorType typeFromNodeType(int nodeType) {
    switch (nodeType) {
      case 0xA8: return DetectorType.vibration;
      case 0xA3: return DetectorType.infraredVolumetric;
      default:   return DetectorType.infraredLinear;
    }
  }

  DetectorModel copyWith({
    DetectorStatus? status,
    int? batteryLevel,
    DateTime? lastSeen,
    int? zone,
    bool? isActive,
    int? alarmCount,
    bool? isArmed,
    int? nodeType,
    Map<String, dynamic>? parameters,
  }) {
    return DetectorModel(
      id: id,
      name: name,
      type: type,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      zone: zone ?? this.zone,
      isActive: isActive ?? this.isActive,
      alarmCount: alarmCount ?? this.alarmCount,
      isArmed: isArmed ?? this.isArmed,
      nodeType: nodeType ?? this.nodeType,
      parameters: parameters ?? this.parameters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'status': status.index,
      'batteryLevel': batteryLevel,
      'lastSeen': lastSeen.toIso8601String(),
      'zone': zone,
      'isActive': isActive ? 1 : 0,
      'alarmCount': alarmCount,
      'isArmed': isArmed ? 1 : 0,
      'nodeType': nodeType,
      'parameters': parameters,
    };
  }

  factory DetectorModel.fromJson(Map<String, dynamic> json) {
    return DetectorModel(
      id: json['id'],
      name: json['name'],
      type: DetectorType.values[json['type']],
      status: DetectorStatus.values[json['status']],
      batteryLevel: json['batteryLevel'] ?? 100,
      lastSeen: DateTime.parse(json['lastSeen']),
      zone: json['zone'] ?? 1,
      isActive: json['isActive'] == 1,
      alarmCount: json['alarmCount'] ?? 0,
      isArmed: json['isArmed'] == 1,
      nodeType: json['nodeType'] ?? 0,
      parameters: json['parameters'] ?? {},
    );
  }

  IconData get icon {
    switch (type) {
      case DetectorType.vibration:
        return Icons.vibration;
      case DetectorType.infraredLinear:
        return Icons.show_chart;
      case DetectorType.infraredVolumetric:
        return Icons.leak_add;
    }
  }

  Color get statusColor {
    if (!isArmed) return Colors.grey;
    switch (status) {
      case DetectorStatus.normal:    return Colors.green;
      case DetectorStatus.alarm:     return Colors.red;
      case DetectorStatus.tamper:    return Colors.purple;
      case DetectorStatus.lowBattery: return Colors.orange;
      case DetectorStatus.offline:   return Colors.grey;
    }
  }

  String get statusText {
    if (!isArmed) return 'Снято';
    switch (status) {
      case DetectorStatus.normal:    return 'Норма';
      case DetectorStatus.alarm:     return 'ТРЕВОГА';
      case DetectorStatus.tamper:    return 'ВСКРЫТИЕ';
      case DetectorStatus.lowBattery: return 'Разряд';
      case DetectorStatus.offline:   return 'Нет связи';
    }
  }

  Color get batteryColor {
    if (batteryLevel > 60) return Colors.green;
    if (batteryLevel > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  String toString() => '$name ($id) - $statusText';
}
