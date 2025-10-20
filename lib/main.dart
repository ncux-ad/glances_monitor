import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const GlancesMonitorApp());
}

class GlancesMonitorApp extends StatelessWidget {
  const GlancesMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glances Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

