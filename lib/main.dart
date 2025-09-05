import 'package:flutter/material.dart';
import 'theme.dart';
import 'auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelGuideBDApp());
}

class TravelGuideBDApp extends StatelessWidget {
  const TravelGuideBDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Guide BD',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
