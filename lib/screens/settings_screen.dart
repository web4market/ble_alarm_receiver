import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

const _kPage    = Color(0xFF0D1117);
const _kSurface = Color(0xFF161B22);
const _kBorder  = Color(0xFF2D3748);
const _kText1   = Color(0xFFD0DDD8);
const _kText2   = Color(0xFF6A8090);
const _kAccBlue = Color(0xFF4FC3F7);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: _kText1,
        title: const Text(
          'НАСТРОЙКИ',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              _SectionHeader('ОТОБРАЖЕНИЕ'),
              const SizedBox(height: 12),
              _FontScaleTile(settings: settings),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: _kText2),
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  final SettingsProvider settings;
  const _FontScaleTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scale = settings.fontScale;
    final pct   = (scale * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Размер шрифта',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kText1)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccBlue.withOpacity(0.15),
                  border: Border.all(color: _kAccBlue.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAccBlue,
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Масштаб текста на основном экране',
            style: const TextStyle(fontSize: 11, color: _kText2),
          ),
          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAccBlue,
              inactiveTrackColor: _kBorder,
              thumbColor: _kAccBlue,
              overlayColor: _kAccBlue.withOpacity(0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: scale,
              min: 0.6,
              max: 2.0,
              divisions: 14,
              onChanged: settings.setFontScale,
            ),
          ),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scaleBtn('−', () => settings.setFontScale(scale - 0.1)),
              Row(children: [
                _presetBtn('60%',  0.6,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('100%', 1.0,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('150%', 1.5,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('200%', 2.0,  scale, settings),
              ]),
              _scaleBtn('+', () => settings.setFontScale(scale + 0.1)),
            ],
          ),

          const SizedBox(height: 16),

          // Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPage,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _kBorder),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Зона 1  •  L50RA LoRa',
                      style: const TextStyle(
                          fontSize: 9, color: _kText2, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  Text('ТРЕВОГА',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA4335))),
                  Text('ID: 0001  •  Контроль',
                      style: const TextStyle(fontSize: 9, color: _kText2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scaleBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _kBorder.withOpacity(0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 18, color: _kText1, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _presetBtn(
      String label, double value, double current, SettingsProvider s) {
    final active = (current - value).abs() < 0.05;
    return GestureDetector(
      onTap: () => s.setFontScale(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _kAccBlue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
              color: active ? _kAccBlue : _kBorder),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? _kAccBlue : _kText2,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}
