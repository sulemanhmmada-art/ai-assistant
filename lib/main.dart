import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _fontFamily = 'Default';
  String _password = '';
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
      _fontFamily = prefs.getString('font_family') ?? 'Default';
      _hasPassword = hasPass;
      _unlocked = false;
      _loaded = true;
    });
  }

  void _updateSettings(Locale locale, double fontSize, String geminiLang) {
    setState(() {
      _locale = locale;
      _fontSize = fontSize;
      _geminiLanguage = geminiLang;
    });
    _loadFontFamily();
  }

  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontFamily = prefs.getString('font_family') ?? 'Default';
    });
  }

  void _onUnlocked(String password) {
    setState(() {
      _password = password;
      _unlocked = true;
      _hasPassword = true;
    });
  }

  TextTheme _buildTextTheme(TextTheme base) {
    TextStyle applyFont(TextStyle? style) {
      if (style == null) return const TextStyle();
      switch (_fontFamily) {
        case 'Cairo':
          return GoogleFonts.cairo(textStyle: style);
        case 'Tajawal':
          return GoogleFonts.tajawal(textStyle: style);
        case 'Almarai':
          return GoogleFonts.almarai(textStyle: style);
        case 'Amiri':
          return GoogleFonts.amiri(textStyle: style);
        case 'Changa':
          return GoogleFonts.changa(textStyle: style);
        default:
          return style;
      }
    }

    return base.copyWith(
      bodyLarge: applyFont(base.bodyLarge),
      bodyMedium: applyFont(base.bodyMedium),
      bodySmall: applyFont(base.bodySmall),
      titleLarge: applyFont(base.titleLarge),
      titleMedium: applyFont(base.titleMedium),
      titleSmall: applyFont(base.titleSmall),
      displayLarge: applyFont(base.displayLarge),
      displayMedium: applyFont(base.displayMedium),
      displaySmall: applyFont(base.displaySmall),
      headlineLarge: applyFont(base.headlineLarge),
      headlineMedium: applyFont(base.headlineMedium),
      headlineSmall: applyFont(base.headlineSmall),
      labelLarge: applyFont(base.labelLarge),
      labelMedium: applyFont(base.labelMedium),
      labelSmall: applyFont(base.labelSmall),
    );
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

    final baseTheme = ThemeData(
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
    );

    return MaterialApp(
      title: 'TalkGPT',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: baseTheme.copyWith(
        textTheme: _buildTextTheme(baseTheme.textTheme),
      ),
      home: !_unlocked
          ? LockScreen(onUnlocked: _onUnlocked)
          : ChatScreen(
              fontSize: _fontSize,
              geminiLanguage: _geminiLanguage,
              locale: _locale,
              password: _password,
              onSettingsChanged: _updateSettings,
            ),
    );
  }
}
