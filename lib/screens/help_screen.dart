import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// Accent colours are stable across themes.
const _kAccBlue  = kAccBlue;
const _kAccGreen = kAccGreen;

// ── Реквизиты правообладателя и служба поддержки ────────────────────────────
// Вынесены в константы, чтобы при необходимости их было легко поменять
// в одном месте.

const _kCompanyName = 'ООО «ЖУРИН ЭЛЕКТРОНИКС»';
const _kCompanyInn  = 'ИНН 5834032400, КПП 583401001';
const _kCompanyAddress =
    '440072, Пензенская область, г. Пенза, ул. Антонова, 3, каб. 410-412';

const _kAppVersion = '1.0.0';

class _Phone {
  final String label;
  final String tel; // цифры для tel:-ссылки
  const _Phone(this.label, this.tel);
}

const _kPhones = [
  _Phone('8 (8412) 20-37-95', '88412203795'),
  _Phone('8 (8412) 51-30-74', '88412513074'),
  _Phone('+79023533074',      '79023533074'),
];

const _kSupportEmail    = 'info@zhurinelectronics.ru';
const _kTelegram        = 'https://t.me/zhurinelectronics';
const _kTelegramLabel   = 't.me/zhurinelectronics';

class _ResourceLink {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  const _ResourceLink(this.icon, this.title, this.subtitle, this.url);
}

const _kResourceLinks = [
  _ResourceLink(Icons.description_outlined, 'Документация',
      'Руководства и инструкции по оборудованию',
      'https://zhurinelectronics.ru/support/download'),
  _ResourceLink(Icons.menu_book_outlined, 'База знаний',
      'Статьи и рекомендации по эксплуатации',
      'https://zhurinelectronics.ru/support/knowledge'),
  _ResourceLink(Icons.build_outlined, 'Применения',
      'Готовые решения и примеры применения',
      'https://zhurinelectronics.ru/support/application'),
  _ResourceLink(Icons.quiz_outlined, 'Вопрос-ответ',
      'Ответы на частые вопросы',
      'https://zhurinelectronics.ru/support/faq'),
];

// ── Общие компоненты (в стиле экрана настроек) ──────────────────────────────

AppBar _helpAppBar(BuildContext context) {
  final c = appColors(context);
  return AppBar(
    backgroundColor: c.surface,
    foregroundColor: c.text1,
    titleSpacing: 0,
    title: const Text('ПОМОЩЬ',
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2)),
    centerTitle: false,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(height: 1, color: c.border),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _kAccBlue)),
      );
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await canLaunchUrl(uri) &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть: $url')),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Экран помощи
// ════════════════════════════════════════════════════════════════════════════

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: _helpAppBar(context),
      body: ListView(
        children: [
          _SectionHeader('ИНСТРУКЦИЯ ПО ИСПОЛЬЗОВАНИЮ'),
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StepItem(
                  number: 1,
                  title: 'Подключение к концентратору',
                  description:
                      'Нажмите на значок Bluetooth в верхней панели, запустите '
                      'поиск и выберите концентратор из списка найденных '
                      'устройств. Чтобы приложение подключалось к нему '
                      'автоматически при следующем запуске, задайте его '
                      'основным на экране «Настройки → Bluetooth».',
                ),
                _StepItem(
                  number: 2,
                  title: 'Экран извещателей',
                  description:
                      'После подключения на главном экране появится сетка '
                      'плиток — по одной на каждый извещатель. Цвет плитки '
                      'показывает её состояние: обычный фон — под охраной и в '
                      'норме, приглушённый — снята с охраны, мигающий красный '
                      'с рамкой — тревога, жёлто-коричневый — разряд батареи, '
                      'тёмный — нет связи. В левом верхнем углу — зона и '
                      'место установки, внизу — модель и ID, справа внизу — '
                      'значки заряда батареи и вскрытия корпуса.',
                ),
                _StepItem(
                  number: 3,
                  title: 'Название зоны и места установки',
                  description:
                      'Нажмите на название зоны в верхней части плитки или на '
                      'строку с местом установки под ним (например, «Окно», '
                      '«Калитка», «Дверь») — откроется окно ввода. Новое '
                      'название сохраняется сразу и используется на всех '
                      'экранах приложения.',
                ),
                _StepItem(
                  number: 4,
                  title: 'Тревоги и их сброс',
                  description:
                      'При срабатывании извещателя его плитка обводится '
                      'красной рамкой, а в правом верхнем углу появляется '
                      'кнопка ✕ — нажмите её, чтобы сбросить тревогу по этому '
                      'извещателю. Кнопка со звонком в верхней панели '
                      'сбрасывает все активные тревоги сразу.',
                ),
                _StepItem(
                  number: 5,
                  title: 'Постановка и снятие с охраны',
                  description:
                      'Кнопка с замком в верхней панели ставит на охрану или '
                      'снимает сразу все извещатели («🔒 ОХРАНА» / «🔓 '
                      'СНЯТО»). Чтобы управлять одним извещателем — нажмите '
                      'на его плитку: справа откроется панель с подробностями '
                      'и кнопками «На охрану» / «Снять».',
                ),
                _StepItem(
                  number: 6,
                  title: 'Журнал событий и экспорт',
                  description:
                      'На панели справа отображается журнал событий. Нажмите '
                      'на извещатель, чтобы показать события только по нему. '
                      'Значок «поделиться» рядом с заголовком журнала '
                      'открывает экспорт — события можно выгрузить в PDF или '
                      'CSV и отправить любым доступным способом.',
                ),
                _StepItem(
                  number: 7,
                  title: 'Настройки приложения',
                  description:
                      'В настройках можно изменить размер шрифта и тему '
                      'оформления (тёмная, светлая или системная), выбрать '
                      'основное BLE-устройство для автоподключения и включить '
                      'или выключить звук тревоги.',
                ),
              ],
            ),
          ),

          _SectionHeader('О ПРИЛОЖЕНИИ'),
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BLE Alarm Receiver',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.text1)),
                const SizedBox(height: 2),
                Text('Версия $_kAppVersion',
                    style: TextStyle(fontSize: 11, color: c.text2)),
                const SizedBox(height: 10),
                Text(
                  'Приложение для приёма сигналов от охранных извещателей по '
                  'Bluetooth Low Energy: мониторинг состояния, постановка и '
                  'снятие с охраны, журнал событий и его экспорт.',
                  style: TextStyle(fontSize: 12, color: c.text1, height: 1.4),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: c.border),
                const SizedBox(height: 14),
                Text('ПРАВООБЛАДАТЕЛЬ',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: c.text2)),
                const SizedBox(height: 8),
                Text(_kCompanyName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text1)),
                const SizedBox(height: 4),
                Text(_kCompanyInn,
                    style: TextStyle(fontSize: 11, color: c.text2)),
                const SizedBox(height: 4),
                Text(_kCompanyAddress,
                    style: TextStyle(fontSize: 11, color: c.text2, height: 1.4)),
              ],
            ),
          ),

          _SectionHeader('ПОДДЕРЖКА'),
          Container(
            color: c.surface,
            child: Column(
              children: [
                for (final p in _kPhones)
                  _LinkRow(
                    icon: Icons.call_outlined,
                    title: p.label,
                    subtitle: 'Телефон',
                    onTap: () => _openUrl(context, 'tel:${p.tel}'),
                  ),
                _LinkRow(
                  icon: Icons.email_outlined,
                  title: _kSupportEmail,
                  subtitle: 'Электронная почта',
                  onTap: () => _openUrl(context, 'mailto:$_kSupportEmail'),
                ),
                _LinkRow(
                  icon: Icons.send_outlined,
                  title: _kTelegramLabel,
                  subtitle: 'Telegram',
                  onTap: () => _openUrl(context, _kTelegram),
                ),
              ],
            ),
          ),

          _SectionHeader('ССЫЛКИ'),
          Container(
            color: c.surface,
            child: Column(
              children: [
                for (final r in _kResourceLinks)
                  _LinkRow(
                    icon: r.icon,
                    title: r.title,
                    subtitle: r.subtitle,
                    onTap: () => _openUrl(context, r.url),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Шаг инструкции ───────────────────────────────────────────────────────────

class _StepItem extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _kAccBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: _kAccBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text1)),
                const SizedBox(height: 3),
                Text(description,
                    style:
                        TextStyle(fontSize: 11.5, color: c.text2, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Строка-ссылка (телефон/почта/сайт) ──────────────────────────────────────

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _kAccGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.text1)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: c.text2)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 15, color: c.text2),
          ],
        ),
      ),
    );
  }
}
