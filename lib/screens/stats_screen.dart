import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/receiver_provider.dart';
import '../models/detector_model.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryCards(provider),
              const SizedBox(height: 20),
              _buildEventsChart(provider),
              const SizedBox(height: 20),
              _buildDetectorsStats(provider),
              const SizedBox(height: 20),
              _buildBatteryStats(provider),
              const SizedBox(height: 20),
              _buildTopDetectors(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(ReceiverProvider provider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Всего событий',
          value: '${provider.events.length}',
          icon: Icons.history,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'Тревог',
          value: '${provider.alarmDetectors}',
          icon: Icons.warning,
          color: Colors.red,
        ),
        _buildStatCard(
          title: 'Активных',
          value: '${provider.activeDetectors}',
          icon: Icons.sensors,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'Нет связи',
          value: '${provider.offlineDetectors}',
          icon: Icons.sensors_off,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsChart(ReceiverProvider provider) {
    var stats = provider.getEventsStats(days: 7);

    // Если нет данных, показываем заглушку
    if (stats.isEmpty) {
      return Card(
        elevation: 4,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Нет данных для отображения'),
          ),
        ),
      );
    }

    double maxY = stats.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Динамика событий (7 дней)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barGroups: stats.entries.map((entry) {
                    return BarChartGroupData(
                      x: stats.keys.toList().indexOf(entry.key),
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.deepPurple,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < stats.keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                stats.keys.elementAt(index),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectorsStats(ReceiverProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Состояние извещателей',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(
              label: 'Норма',
              value: provider.activeDetectors - provider.alarmDetectors -
                  provider.tamperDetectors - provider.lowBatteryDetectors,
              total: provider.totalDetectors,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              label: 'Тревога',
              value: provider.alarmDetectors,
              total: provider.totalDetectors,
              color: Colors.red,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              label: 'Вскрытие',
              value: provider.tamperDetectors,
              total: provider.totalDetectors,
              color: Colors.purple,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              label: 'Разряд',
              value: provider.lowBatteryDetectors,
              total: provider.totalDetectors,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildProgressBar(
              label: 'Нет связи',
              value: provider.offlineDetectors,
              total: provider.totalDetectors,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    double percentage = total > 0 ? value / total : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value (${(percentage * 100).toStringAsFixed(1)}%)'),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryStats(ReceiverProvider provider) {
    int good = provider.detectors.where((d) => d.batteryLevel > 60).length;
    int medium = provider.detectors.where((d) => d.batteryLevel <= 60 && d.batteryLevel > 20).length;
    int low = provider.detectors.where((d) => d.batteryLevel <= 20).length;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Состояние батарей',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildBatteryPieChart(good, medium, low),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBatteryLegend('Хороший (>60%)', good, Colors.green),
                      const SizedBox(height: 8),
                      _buildBatteryLegend('Средний (20-60%)', medium, Colors.orange),
                      const SizedBox(height: 8),
                      _buildBatteryLegend('Низкий (<20%)', low, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryPieChart(int good, int medium, int low) {
    int total = good + medium + low;
    if (total == 0) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Нет данных'),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: good.toDouble(),
              color: Colors.green,
              title: '${((good / total) * 100).toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: medium.toDouble(),
              color: Colors.orange,
              title: '${((medium / total) * 100).toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: low.toDouble(),
              color: Colors.red,
              title: '${((low / total) * 100).toStringAsFixed(0)}%',
              radius: 50,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
          sectionsSpace: 0,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }

  Widget _buildBatteryLegend(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTopDetectors(ReceiverProvider provider) {
    if (provider.detectors.isEmpty) {
      return const SizedBox.shrink();
    }

    var topDetectors = List<DetectorModel>.from(provider.detectors)
      ..sort((a, b) => b.alarmCount.compareTo(a.alarmCount));

    if (topDetectors.isEmpty || topDetectors.first.alarmCount == 0) {
      return const SizedBox.shrink();
    }

    topDetectors = topDetectors.take(5).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Наиболее активные извещатели',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(topDetectors.length, (index) {
              final detector = topDetectors[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detector.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Срабатываний: ${detector.alarmCount}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: detector.statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        detector.statusText,
                        style: TextStyle(
                          color: detector.statusColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}