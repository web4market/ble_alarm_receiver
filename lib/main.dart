import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/receiver_provider.dart';
import 'providers/settings_provider.dart';
import 'services/api_sync_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReceiverProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        // Отправка журнала на сервер — работает в фоне всё время работы приложения
        ChangeNotifierProvider.value(value: ApiSyncService()..start()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, __) => MaterialApp(
          title: 'Zhurin Electronics — Alarm',
          theme:      AppTheme.light(),
          darkTheme:  AppTheme.dark(),
          themeMode:  settings.themeMode,
          // Единый масштаб шрифта для всего приложения (см. kBaseFontScale)
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: appTextScaler(settings.fontScale)),
            child: child!,
          ),
          // Первый запуск: выбор языка → ввод пин-кода → главный экран.
          // После сброса до заводских установок снова попадаем сюда.
          home: !settings.isLoaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : settings.needsLanguage
                  ? const LanguageSelectScreen()
                  : settings.needsPin
                      ? const PinSetupScreen()
                      : const MainScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
