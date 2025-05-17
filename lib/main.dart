import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const HearMeOutApp());
}

class HearMeOutApp extends StatelessWidget {
  const HearMeOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HearMeOut',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00C853),
          secondary: const Color(0xFF00C853),
          background: Colors.black,
          surface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}
