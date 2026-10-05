import 'package:flutter/material.dart';
import 'background_widgets.dart';
import 'lock_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'app_drawer.dart';

void main() {
  runApp(const TalkGPTApp());
}

class TalkGPTApp extends StatelessWidget {
  const TalkGPTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkGPT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070913),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF6C5CE7),
        ),
      ),
      home: const MainAppWrapper(),
    );
  }
}

class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  bool _isUnlocked = false; // يمكنك تغييرها إلى false لتفعيل شاشة القفل أولاً
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // 1. عرض شاشة القفل إذا لم يتم الدخول بعد
    if (!_isUnlocked) {
      return LockScreen(
        correctPassword: '1234', // كلمة المرور الافتراضية
        onUnlocked: () {
          setState(() {
            _isUnlocked = true;
          });
        },
      );
    }

    // 2. الواجهة الرئيسية بالتصميم الموحد والقائمة الجانبية
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onNewChat: () {
          // إعادة ضبط المحادثة عند الضغط على محادثة جديدة
          setState(() {});
        },
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      ),
      body: ChatScreen(
        onOpenDrawer: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }
}
