import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receiver_provider.dart';
import 'detectors_screen.dart';
import 'events_screen.dart';
import 'zones_screen.dart';
import 'stats_screen.dart';
import 'help_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Приемник сигналов'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Consumer<ReceiverProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  if (provider.isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bluetooth_connected, size: 16),
                          SizedBox(width: 4),
                          Text('Подключено'),
                        ],
                      ),
                    ),
                  if (provider.unreadEvents > 0)
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications),
                          onPressed: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                            provider.markEventsAsRead();
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${provider.unreadEvents}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    icon: const Icon(Icons.bluetooth_searching),
                    onPressed: () => _showConnectionDialog(context, provider),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DetectorsScreen(),
          EventsScreen(),
          ZonesScreen(),
          StatsScreen(),
          HelpScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Извещатели',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'События',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Зоны',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help),
            label: 'Помощь',
          ),
        ],
      ),
    );
  }

  void _showConnectionDialog(BuildContext context, ReceiverProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Управление подключением',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (provider.isConnected) ...[
                  ListTile(
                    leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
                    title: Text('Подключено к ${provider.connectedHub?.platformName ?? 'концентратору'}'),
                    subtitle: Text('ID: ${provider.connectedHub?.remoteId ?? ''}'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.disconnectFromHub();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Отключиться'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ] else ...[
                  if (provider.isScanning) ...[
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Поиск концентраторов...'),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.startScanning();
                      },
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Начать поиск'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: provider.discoveredHubs.length,
                      itemBuilder: (context, index) {
                        final hub = provider.discoveredHubs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.hub, color: Colors.deepPurple),
                            title: Text(hub.platformName.isNotEmpty ? hub.platformName : 'Концентратор'),
                            subtitle: Text(hub.remoteId.toString()),
                            trailing: ElevatedButton(
                              onPressed: () {
                                provider.connectToHub(hub);
                                Navigator.pop(context);
                              },
                              child: const Text('Подключить'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}