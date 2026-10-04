import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

// Экраны первого запуска: выбор языка и ввод пин-кода.
// Показываются из MyApp (main.dart), пока соответствующая настройка не
// сохранена в базе. После сброса до заводских установок — снова.

const int kPinMinLength = 4;
const int kPinMaxLength = 8;

class _OnboardingFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ZHURIN ELECTRONICS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: kAccBlue)),
                  const SizedBox(height: 24),
                  Icon(icon, size: 44, color: kAccBlue),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.text1)),
                  const SizedBox(height: 8),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.text2)),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 1. Выбор языка ───────────────────────────────────────────────────────────

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String _selected = SettingsProvider.availableLanguages.keys.first;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return _OnboardingFrame(
      icon: Icons.language,
      title: 'Выберите язык',
      subtitle: 'Язык, на котором будет отображаться информация',
      child: Column(
        children: [
          ...SettingsProvider.availableLanguages.entries.map((e) {
            final active = e.key == _selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selected = e.key),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: active ? kAccBlue.withOpacity(0.15) : c.surface,
                    border: Border.all(
                        color: active ? kAccBlue : c.border,
                        width: active ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text1)),
                    ),
                    if (active)
                      const Icon(Icons.check_circle, color: kAccBlue, size: 20),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Продолжить',
            onTap: () => context.read<SettingsProvider>().setLanguage(_selected),
          ),
        ],
      ),
    );
  }
}

// ── 2. Ввод пин-кода ─────────────────────────────────────────────────────────

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pin.text;
    if (pin.length < kPinMinLength) {
      setState(() => _error = 'Пин-код должен содержать не менее $kPinMinLength цифр');
      return;
    }
    if (pin != _confirm.text) {
      setState(() => _error = 'Пин-коды не совпадают');
      return;
    }
    context.read<SettingsProvider>().setPinCode(pin);
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingFrame(
      icon: Icons.lock_outline,
      title: 'Придумайте пин-код',
      subtitle: 'Пин-код понадобится для сброса приложения до заводских '
          'установок. Запомните его — восстановить пин-код нельзя.',
      child: Column(
        children: [
          PinField(controller: _pin, label: 'Пин-код', autofocus: true),
          const SizedBox(height: 12),
          PinField(
              controller: _confirm,
              label: 'Повторите пин-код',
              onSubmitted: (_) => _save()),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: kAccRed)),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(label: 'Сохранить', onTap: _save),
        ],
      ),
    );
  }
}

// ── Общие элементы ───────────────────────────────────────────────────────────

class PinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: kPinMaxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      style: TextStyle(
          fontSize: 20, letterSpacing: 8, color: c.text1, fontFamily: 'monospace'),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: kAccBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
    );
  }
}
