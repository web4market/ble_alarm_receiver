import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/receiver_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_model.dart';
import 'dart:convert';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _searchQuery;
  final List<bool> _selectedTypes = List.filled(12, false);

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            _buildFilterBar(context, provider),
            Expanded(
              child: provider.events.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Нет событий'),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: provider.events.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final event = provider.events[index];
                  return _buildEventCard(event);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context, ReceiverProvider provider) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Экспорт',
                  icon: Icons.share,
                  color: Colors.green,
                  onTap: () => _showExportDialog(context, provider),
                ),
                _buildFilterChip(
                  label: 'Все',
                  icon: Icons.list,
                  color: Colors.blue,
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _searchQuery = null;
                    });
                  },
                ),
                _buildFilterChip(
                  label: 'Тревоги',
                  icon: Icons.warning,
                  color: Colors.red,
                  onTap: () => _filterByType(EventType.alarm),
                ),
                _buildFilterChip(
                  label: 'Вскрытие',
                  icon: Icons.lock_open,
                  color: Colors.purple,
                  onTap: () => _filterByType(EventType.tamper),
                ),
                _buildFilterChip(
                  label: 'Разряд',
                  icon: Icons.battery_alert,
                  color: Colors.orange,
                  onTap: () => _filterByType(EventType.lowBattery),
                ),
                _buildFilterChip(
                  label: 'Система',
                  icon: Icons.system_security_update,
                  color: Colors.blueGrey,
                  onTap: () => _filterSystemEvents(),
                ),
              ],
            ),
          ),
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Фильтр: ${_startDate != null ? DateFormat('dd.MM.yy').format(_startDate!) : '...'} - ${_endDate != null ? DateFormat('dd.MM.yy').format(_endDate!) : '...'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: event.isRead ? null : event.color.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.color.withOpacity(0.2),
          child: Icon(event.icon, color: event.color, size: 20),
        ),
        title: Text(
          event.description,
          style: TextStyle(
            fontWeight: event.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('dd.MM.yy HH:mm:ss').format(event.timestamp)} | ${event.detectorName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: event.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getEventTypeShort(event.type),
            style: TextStyle(
              color: event.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  void _filterByType(EventType type) {
    setState(() {
      // Реализация фильтрации
    });
  }

  void _filterSystemEvents() {
    setState(() {
      // Фильтр системных событий
    });
  }

  void _showExportDialog(BuildContext context, ReceiverProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Экспорт событий'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('За сегодня'),
              onTap: () {
                Navigator.pop(context);
                _exportEvents(provider, DateTime.now().subtract(const Duration(days: 1)), DateTime.now());
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('За неделю'),
              onTap: () {
                Navigator.pop(context);
                _exportEvents(provider, DateTime.now().subtract(const Duration(days: 7)), DateTime.now());
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('За месяц'),
              onTap: () {
                Navigator.pop(context);
                _exportEvents(provider, DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
              },
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Все события'),
              onTap: () {
                Navigator.pop(context);
                _exportEvents(provider, null, null);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _exportEvents(ReceiverProvider provider, DateTime? start, DateTime? end) async {
    String csv = provider.exportEventsToCsv(startDate: start, endDate: end);

    try {
      // Получаем директорию для временных файлов
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/events_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv, encoding: utf8);

      // Отправляем файл
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Экспорт событий сигнализации',
        subject: 'Журнал событий',
      );
    } catch (e) {
      debugPrint('Ошибка экспорта: $e');
      // Если не удалось сохранить файл, показываем текст
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Экспорт событий'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Не удалось создать файл. Скопируйте текст:'),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(csv),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showEventDetails(EventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getEventTypeName(event.type)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Описание: ${event.description}'),
            const SizedBox(height: 8),
            Text('Извещатель: ${event.detectorName}'),
            Text('ID: ${event.detectorId}'),
            Text('Время: ${DateFormat('dd.MM.yy HH:mm:ss').format(event.timestamp)}'),
            if (event.data != null) ...[
              const Divider(),
              const Text('Дополнительные данные:'),
              ...event.data!.entries.map((e) => Text('${e.key}: ${e.value}')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _getEventTypeShort(EventType type) {
    switch (type) {
      case EventType.alarm:
        return 'ТРВ';
      case EventType.tamper:
        return 'ВСК';
      case EventType.lowBattery:
        return 'БАТ';
      case EventType.restored:
        return 'ВОС';
      case EventType.connected:
        return 'ПДК';
      case EventType.disconnected:
        return 'ОТК';
      case EventType.armed:
        return 'ОХР';
      case EventType.disarmed:
        return 'СНЯ';
      case EventType.systemArmed:
        return 'С_ОХР';
      case EventType.systemDisarmed:
        return 'С_СНЯ';
      case EventType.zoneArmed:
        return 'З_ОХР';
      case EventType.zoneDisarmed:
        return 'З_СНЯ';
    }
  }

  String _getEventTypeName(EventType type) {
    switch (type) {
      case EventType.alarm:
        return 'Тревога';
      case EventType.tamper:
        return 'Вскрытие';
      case EventType.lowBattery:
        return 'Низкий заряд';
      case EventType.restored:
        return 'Восстановление';
      case EventType.connected:
        return 'Подключение';
      case EventType.disconnected:
        return 'Отключение';
      case EventType.armed:
        return 'Постановка на охрану';
      case EventType.disarmed:
        return 'Снятие с охраны';
      case EventType.systemArmed:
        return 'Система под охраной';
      case EventType.systemDisarmed:
        return 'Система снята';
      case EventType.zoneArmed:
        return 'Зона под охраной';
      case EventType.zoneDisarmed:
        return 'Зона снята';
    }
  }
}