import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receiver_provider.dart';
import '../models/detector_model.dart';

class DetectorsScreen extends StatelessWidget {
  const DetectorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverProvider>(
      builder: (context, provider, child) {
        if (provider.detectors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sensors_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Нет подключенных извещателей',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                if (!provider.isConnected)
                  ElevatedButton(
                    onPressed: () {
                      // Открываем диалог подключения
                    },
                    child: const Text('Подключиться к концентратору'),
                  ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsBar(provider),
            Expanded(
              child: ListView.builder(
                itemCount: provider.detectors.length,
                itemBuilder: (context, index) {
                  final detector = provider.detectors[index];
                  return _buildDetectorCard(detector, provider, context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(ReceiverProvider provider) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.deepPurple.shade50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatChip('Всего', provider.totalDetectors, Colors.blue),
            _buildStatChip('Тревога', provider.alarmDetectors, Colors.red),
            _buildStatChip('Вскрытие', provider.tamperDetectors, Colors.purple),
            _buildStatChip('Разряд', provider.lowBatteryDetectors, Colors.orange),
            _buildStatChip('Нет связи', provider.offlineDetectors, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectorCard(DetectorModel detector, ReceiverProvider provider, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: detector.statusColor.withOpacity(0.2),
            child: Icon(detector.icon, color: detector.statusColor),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  detector.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!detector.isArmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Снято',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${detector.id} | Зона: ${detector.zone}'),
              Row(
                children: [
                  Icon(Icons.battery_full, size: 16, color: detector.batteryColor),
                  const SizedBox(width: 4),
                  Text('${detector.batteryLevel}%'),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatLastSeen(detector.lastSeen),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: detector.statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              detector.statusText,
              style: TextStyle(
                color: detector.statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.notifications_off,
                        label: 'Сброс тревоги',
                        color: Colors.orange,
                        onPressed: detector.status == DetectorStatus.alarm ||
                            detector.status == DetectorStatus.tamper
                            ? () => provider.disarmDetectorAlarm(detector.id)
                            : null,
                      ),
                      _buildActionButton(
                        icon: Icons.security,
                        label: detector.isArmed ? 'Снять с охраны' : 'Поставить',
                        color: detector.isArmed ? Colors.orange : Colors.green,
                        onPressed: () {
                          if (detector.isArmed) {
                            provider.disarmDetector(detector.id);
                          } else {
                            provider.armDetector(detector.id);
                          }
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.info,
                        label: 'Детали',
                        color: Colors.blue,
                        onPressed: () => _showDetectorDetails(context, detector),
                      ),
                    ],
                  ),
                  if (detector.alarmCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Срабатываний: ${detector.alarmCount}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: onPressed != null ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: onPressed != null ? color : Colors.grey),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: onPressed != null ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    var now = DateTime.now();
    var difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else {
      return '${difference.inDays} дн назад';
    }
  }

  void _showDetectorDetails(BuildContext context, DetectorModel detector) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(detector.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID', detector.id),
              _buildDetailRow('Тип', _getTypeName(detector.type)),
              _buildDetailRow('Зона', '${detector.zone}'),
              _buildDetailRow('Статус', detector.statusText, color: detector.statusColor),
              _buildDetailRow('Батарея', '${detector.batteryLevel}%'),
              _buildDetailRow('Последняя связь', _formatDateTime(detector.lastSeen)),
              _buildDetailRow('Срабатываний', '${detector.alarmCount}'),
              if (detector.parameters.isNotEmpty) ...[
                const Divider(),
                const Text('Параметры:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...detector.parameters.entries.map((e) =>
                    _buildDetailRow(e.key, e.value.toString())
                ),
              ],
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

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getTypeName(DetectorType type) {
    switch (type) {
      case DetectorType.vibration:
        return 'Вибрационный';
      case DetectorType.infraredLinear:
        return 'ИК Линейный';
      case DetectorType.infraredVolumetric:
        return 'ИК Объемный';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}