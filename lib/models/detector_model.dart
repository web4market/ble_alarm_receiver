import 'package:flutter/material.dart';

enum DetectorType { vibration, infraredLinear, infraredVolumetric }
enum DetectorStatus { normal, alarm, tamper, lowBattery, offline }

class DetectorModel {
  final String id;
  final String name;
  final DetectorType type;
  DetectorStatus status;
  int batteryLevel;
  DateTime lastSeen;
  int zone;
  bool isActive;
  int alarmCount;
  bool isArmed;
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
    this.parameters = const {},
  }) : lastSeen = lastSeen ?? DateTime.now();

  // Копирование с изменениями
  DetectorModel copyWith({
    DetectorStatus? status,
    int? batteryLevel,
    DateTime? lastSeen,
    int? zone,
    bool? isActive,
    int? alarmCount,
    bool? isArmed,
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
      parameters: parameters ?? this.parameters,
    );
  }

  // Конвертация в JSON для хранения
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
      'parameters': parameters,
    };
  }

  // Создание из JSON
  factory DetectorModel.fromJson(Map<String, dynamic> json) {
    return DetectorModel(
      id: json['id'],
      name: json['name'],
      type: DetectorType.values[json['type']],
      status: DetectorStatus.values[json['status']],
      batteryLevel: json['batteryLevel'],
      lastSeen: DateTime.parse(json['lastSeen']),
      zone: json['zone'],
      isActive: json['isActive'] == 1,
      alarmCount: json['alarmCount'],
      isArmed: json['isArmed'] == 1,
      parameters: json['parameters'] ?? {},
    );
  }

  // Получение иконки
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

  // Цвет статуса
  Color get statusColor {
    if (!isArmed) return Colors.grey;
    switch (status) {
      case DetectorStatus.normal:
        return Colors.green;
      case DetectorStatus.alarm:
        return Colors.red;
      case DetectorStatus.tamper:
        return Colors.purple;
      case DetectorStatus.lowBattery:
        return Colors.orange;
      case DetectorStatus.offline:
        return Colors.grey;
    }
  }

  // Текст статуса
  String get statusText {
    if (!isArmed) return 'Снято';
    switch (status) {
      case DetectorStatus.normal:
        return 'Норма';
      case DetectorStatus.alarm:
        return 'ТРЕВОГА';
      case DetectorStatus.tamper:
        return 'ВСКРЫТИЕ';
      case DetectorStatus.lowBattery:
        return 'Разряд';
      case DetectorStatus.offline:
        return 'Нет связи';
    }
  }

  // Цвет батареи
  Color get batteryColor {
    if (batteryLevel > 60) return Colors.green;
    if (batteryLevel > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  String toString() {
    return '$name ($id) - $statusText, батарея: $batteryLevel%';
  }
}