import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/receiver_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';
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
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, __) => MaterialApp(
          title: 'Zhurin Electronics — Alarm',
          theme:      AppTheme.light(),
          darkTheme:  AppTheme.dark(),
          themeMode:  settings.themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
