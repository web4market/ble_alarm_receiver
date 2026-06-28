import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/receiver_provider.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReceiverProvider(),
      child: MaterialApp(
        title: 'Zhurin Electronics — Alarm',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4FC3F7),
            brightness: Brightness.dark,
            surface: const Color(0xFF161B22),
          ),
          dividerColor: const Color(0xFF2D3748),
          dialogBackgroundColor: const Color(0xFF161B22),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF161B22),
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}