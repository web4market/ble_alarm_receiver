import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receiver_provider.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  final List<Map<String, dynamic>> _zones = [
    {'id': 1, 'name': 'Зона 1 - Вход', 'isArmed': true, 'detectors': 4},
    {'id': 2, 'name': 'Зона 2 - Окна', 'isArmed': true, 'detectors': 6},
    {'id': 3, 'name': 'Зона 3 - Зал', 'isArmed': true, 'detectors': 3},
    {'id': 4, 'name': 'Зона 4 - Спальни', 'isArmed': true, 'detectors': 5},
    {'id': 5, 'name': 'Зона 5 - Гараж', 'isArmed': false, 'detectors': 2},
    {'id': 6, 'name': 'Зона 6 - Техническая', 'isArmed': false, 'detectors': 1},
    {'id': 7, 'name': 'Зона 7 - Двор', 'isArmed': true, 'detectors': 3},
    {'id': 8, 'name': 'Зона 8 - Периметр', 'isArmed': true, 'detectors': 4},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            _buildControlBar(provider),
            Expanded(
              child: ListView.builder(
                itemCount: _zones.length,
                itemBuilder: (context, index) {
                  final zone = _zones[index];
                  return _buildZoneCard(zone, provider);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlBar(ReceiverProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.deepPurple.shade50,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.armAll,
              icon: const Icon(Icons.shield),
              label: const Text('Поставить все'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.disarmAllAlarms,
              icon: const Icon(Icons.notifications_off),
              label: const Text('Сброс тревог'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.disarmAll,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Снять все'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone, ReceiverProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: zone['isArmed'] ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          child: Icon(
            zone['isArmed'] ? Icons.shield : Icons.shield_outlined,
            color: zone['isArmed'] ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(zone['name']),
        subtitle: Text('${zone['detectors']} извещателей'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: zone['isArmed'] ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            zone['isArmed'] ? 'Под охраной' : 'Снято',
            style: TextStyle(
              color: zone['isArmed'] ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildZoneAction(
                  icon: Icons.shield,
                  label: 'Поставить',
                  color: Colors.green,
                  onPressed: zone['isArmed']
                      ? null
                      : () => provider.armZone(zone['id']),
                ),
                _buildZoneAction(
                  icon: Icons.shield_outlined,
                  label: 'Снять',
                  color: Colors.orange,
                  onPressed: zone['isArmed']
                      ? () => provider.disarmZone(zone['id'])
                      : null,
                ),
                _buildZoneAction(
                  icon: Icons.notifications_off,
                  label: 'Сброс',
                  color: Colors.blue,
                  onPressed: () {
                    // Сброс тревог в зоне
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneAction({
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
}