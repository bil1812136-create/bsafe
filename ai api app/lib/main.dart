import 'package:flutter/material.dart';

import 'package:ai_api_classifier/l10n/app_i18n.dart';
import 'package:ai_api_classifier/screens/ai_api_batch_screen.dart';
import 'package:ai_api_classifier/screens/report_screen.dart';

void main() {
  runApp(const AiApiBatchApp());
}

class AiApiBatchApp extends StatefulWidget {
  const AiApiBatchApp({super.key});

  @override
  State<AiApiBatchApp> createState() => _AiApiBatchAppState();
}

class _AiApiBatchAppState extends State<AiApiBatchApp> {
  AppLanguage _language = AppLanguage.zh;

  void _onLanguageChanged(AppLanguage language) {
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(_language);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: i18n.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7285)),
        useMaterial3: true,
      ),
      home: AiApiBatchScreen(
        language: _language,
        onLanguageChanged: _onLanguageChanged,
      ),
      onGenerateRoute: (settings) {
        if (settings.name == ReportScreen.routeName) {
          return MaterialPageRoute<void>(
            builder: (_) => ReportScreen(language: _language),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
