import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;
  final String password;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
    required this.password,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontSize;
  late String _geminiLanguage;
  late Locale _locale;

  bool get _isArabic => _locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _geminiLanguage = widget.geminiLanguage;
    _locale = widget.locale;
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  Future<void> _saveGeminiLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_language', lang);
  }

  Future<void> _saveAppLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }

  void _returnResult() {
    Navigator.pop(context, {
      'locale': _locale,
      'fontSize': _fontSize,
      'geminiLanguage': _geminiLanguage,
    });
  }

  Future<void> _deleteAllConversations() async {
