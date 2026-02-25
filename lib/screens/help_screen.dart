import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'О приложении',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'BLE Alarm Receiver v1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Приложение для приема сигналов от охранных извещателей '
                      'по Bluetooth Low Energy. Позволяет мониторить состояние '
                      'извещателей, управлять охраной и просматривать журнал событий.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Функциональность',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.sensors,
                  title: 'Мониторинг извещателей',
                  description: 'Отображение статуса всех подключенных извещателей, их типа, уровня заряда и времени последней связи.',
                ),
                _buildHelpItem(
                  icon: Icons.warning,
                  title: 'Тревоги',
                  description: 'Отображение активных тревог с цветовой индикацией. Возможность отключать тревоги по одному или все сразу.',
                ),
                _buildHelpItem(
                  icon: Icons.shield,
                  title: 'Управление охраной',
                  description: 'Постановка и снятие с охраны отдельных извещателей, целых зон или всей системы сразу.',
                ),
                _buildHelpItem(
                  icon: Icons.history,
                  title: 'Журнал событий',
                  description: 'Запись всех событий системы с возможностью фильтрации, поиска и экспорта в CSV.',
                ),
                _buildHelpItem(
                  icon: Icons.map,
                  title: 'Зоны',
                  description: 'Группировка извещателей по зонам для удобного управления.',
                ),
                _buildHelpItem(
                  icon: Icons.bar_chart,
                  title: 'Статистика',
                  description: 'Визуализация данных о работе системы, графики событий, состояние батарей.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Использование',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStepItem(
                  number: 1,
                  title: 'Подключение',
                  description: 'Нажмите на иконку Bluetooth в верхней панели, запустите поиск и выберите концентратор для подключения.',
                ),
                _buildStepItem(
                  number: 2,
                  title: 'Мониторинг',
                  description: 'После подключения вы увидите список всех зарегистрированных извещателей и их текущий статус.',
                ),
                _buildStepItem(
                  number: 3,
                  title: 'Управление',
                  description: 'Используйте кнопки на карточках извещателей для управления. На экране зон доступно групповое управление.',
                ),
                _buildStepItem(
                  number: 4,
                  title: 'Экспорт данных',
                  description: 'На экране событий нажмите кнопку "Экспорт" для выгрузки журнала в CSV-файл и отправки по email.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Поддержка',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.blue),
                  title: const Text('Техническая поддержка'),
                  subtitle: const Text('support@alarmsystem.com'),
                  onTap: () => _launchEmail(),
                ),
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.green),
                  title: const Text('Документация'),
                  subtitle: const Text('Руководство пользователя'),
                  onTap: () => _launchUrl('https://example.com/docs'),
                ),
                ListTile(
                  leading: const Icon(Icons.update, color: Colors.orange),
                  title: const Text('Версия приложения'),
                  subtitle: const Text('1.0.0 (собрано 24.02.2026)'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@alarmsystem.com',
      query: 'subject=Поддержка BLE Alarm Receiver',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}