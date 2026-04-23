import 'package:flutter/material.dart';

import 'package:ai_api_classifier/l10n/app_i18n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.language;
  }

  void _onSelect(AppLanguage language) {
    setState(() {
      _selected = language;
    });
    widget.onLanguageChanged(language);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(_selected);
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            i18n.language,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          RadioListTile<AppLanguage>(
            value: AppLanguage.zh,
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) _onSelect(value);
            },
            title: const Text('中文'),
          ),
          RadioListTile<AppLanguage>(
            value: AppLanguage.en,
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) _onSelect(value);
            },
            title: const Text('English'),
          ),
        ],
      ),
    );
  }
}
