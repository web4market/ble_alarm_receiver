import 'package:flutter/material.dart';

enum EventType {
  alarm,
  tamper,
  lowBattery,
  restored,
  connected,
  disconnected,
  armed,
  disarmed,
  systemArmed,
  systemDisarmed,
  zoneArmed,
  zoneDisarmed,
  // Новые типы добавляются ТОЛЬКО в конец: в БД хранится индекс enum.
  detectorAdded,     // извещатель запрограммирован (код 0x54)
  detectorRemoved,   // извещатель удалён из базы
  btConnected,       // подключение к BT-концентратору
  btLost,            // потеря связи с BT-концентратором
  btManualDisconnect,// ручное отключение BT пользователем
  btAdapterOff,      // Bluetooth выключен на планшете
  btAdapterOn,       // Bluetooth включён на планшете
  tabletBatteryLow,  // низкий заряд батареи планшета
}

class EventModel {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final String detectorId;
  final String detectorName;
  final String description;
  final Map<String, dynamic>? data;
  bool isRead;

  EventModel({
    String? id,
    required this.timestamp,
    required this.type,
    required this.detectorId,
    required this.detectorName,
    required this.description,
    this.data,
    this.isRead = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'detectorId': detectorId,
      'detectorName': detectorName,
      'description': description,
      'data': data,
      'isRead': isRead ? 1 : 0,
    };
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: EventType.values[json['type']],
      detectorId: json['detectorId'],
      detectorName: json['detectorName'],
      description: json['description'],
      data: json['data'],
      isRead: json['isRead'] == 1,
    );
  }

  IconData get icon {
    switch (type) {
      case EventType.alarm:
        return Icons.warning;
      case EventType.tamper:
        return Icons.lock_open;
      case EventType.lowBattery:
        return Icons.battery_alert;
      case EventType.restored:
        return Icons.check_circle;
      case EventType.connected:
        return Icons.bluetooth_connected;
      case EventType.disconnected:
        return Icons.bluetooth_disabled;
      case EventType.armed:
        return Icons.security;
      case EventType.disarmed:
        return Icons.security;
      case EventType.systemArmed:
        return Icons.shield;
      case EventType.systemDisarmed:
        return Icons.shield_outlined;
      case EventType.zoneArmed:
        return Icons.maps_home_work;
      case EventType.zoneDisarmed:
        return Icons.maps_home_work_outlined;
      case EventType.detectorAdded:
        return Icons.add_circle_outline;
      case EventType.detectorRemoved:
        return Icons.remove_circle_outline;
      case EventType.btConnected:
        return Icons.bluetooth_connected;
      case EventType.btLost:
        return Icons.bluetooth_disabled;
      case EventType.btManualDisconnect:
        return Icons.bluetooth;
      case EventType.btAdapterOff:
        return Icons.bluetooth_disabled;
      case EventType.btAdapterOn:
        return Icons.bluetooth;
      case EventType.tabletBatteryLow:
        return Icons.battery_alert;
    }
  }

  Color get color {
    switch (type) {
      case EventType.alarm:
        return Colors.red;
      case EventType.tamper:
        return Colors.purple;
      case EventType.lowBattery:
        return Colors.orange;
      case EventType.restored:
        return Colors.green;
      case EventType.connected:
        return Colors.blue;
      case EventType.disconnected:
        return Colors.grey;
      case EventType.armed:
      case EventType.systemArmed:
      case EventType.zoneArmed:
        return Colors.green;
      case EventType.disarmed:
      case EventType.systemDisarmed:
      case EventType.zoneDisarmed:
        return Colors.orange;
      case EventType.detectorAdded:
        return Colors.blue;
      case EventType.detectorRemoved:
        return Colors.grey;
      case EventType.btConnected:
      case EventType.btAdapterOn:
        return Colors.blue;
      case EventType.btLost:
      case EventType.btAdapterOff:
        return Colors.red;
      case EventType.btManualDisconnect:
        return Colors.grey;
      case EventType.tabletBatteryLow:
        return Colors.orange;
    }
  }
}