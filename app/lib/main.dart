import 'package:flutter/material.dart';
import 'package:psychosims/app/screens/home_screen.dart';

void main() {
  runApp(const PsychosimsApp());
}

class PsychosimsApp extends StatelessWidget {
  const PsychosimsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psychosims',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
