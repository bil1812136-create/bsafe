import 'package:flutter/material.dart';

import 'package:ai_api_classifier/screens/ai_api_batch_screen.dart';
import 'package:ai_api_classifier/screens/report_screen.dart';

void main() {
  runApp(const AiApiBatchApp());
}

class AiApiBatchApp extends StatelessWidget {
  const AiApiBatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI API Batch Classifier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7285)),
        useMaterial3: true,
      ),
      routes: {
        ReportScreen.routeName: (_) => const ReportScreen(),
      },
      home: const AiApiBatchScreen(),
    );
  }
}
