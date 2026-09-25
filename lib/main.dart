import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import 'chat_screen.dart';
import 'lock_screen.dart';

void main() {
  runApp(const TalkGPTApp());
}

class TalkGPTApp extends StatefulWidget {
  const TalkGPTApp({super.key});

  @override
  State<TalkGPTApp> createState() => _TalkGPTAppState();
}

class _TalkGPTAppState extends State<TalkGPTApp> {
  Locale _locale = const Locale('ar');
  double _fontSize = 14.0;
  String _geminiLanguage = 'ar';
  bool _loaded = false;
  bool _hasPassword = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPass = await MemoryService.hasPassword();

    setState(() {
      _locale = Locale(prefs.getString('app_language') ?? 'ar');
      _fontSize = prefs.getDouble('font_size') ?? 14.0;
      _geminiLanguage = prefs.getString('gemini_language') ?? 'ar';
      _hasPassword = hasPass;
      _unlocked = !hasPass;
      _loaded = true;
    });
  }

  void _updateSettings(Locale locale, double fontSize, String geminiLang) {
    setState(() {
      _locale = locale;
      _fontSize = fontSize;
      _geminiLanguage = geminiLang;
    });
  }

  void _onUnlocked() {
    setState(() {
      _unlocked = true;
      _hasPassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0E1116),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF10A37F)),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'TalkGPT',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10A37F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1116),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1116),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: !_unlocked
          ? LockScreen(onUnlocked: _onUnlocked)
          : ChatScreen(
              fontSize: _fontSize,
              geminiLanguage: _geminiLanguage,
              locale: _locale,
              onSettingsChanged: _updateSettings,
            ),
    );
  }
}
