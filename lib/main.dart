import 'package:flutter/material.dart';

void main() {
runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'المساعد الذكي',
debugShowCheckedModeBanner: false,
theme: ThemeData(
primarySwatch: Colors.blue,
brightness: Brightness.dark,
),
home: const HomePage(),
);
}
}

class HomePage extends StatelessWidget {
const HomePage({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('المساعد الذكي'),
centerTitle: true,
),
body: const Center(
child: Padding(
padding: EdgeInsets.all(24.0),
child: Text(
'مرحباً بك في المساعد الذكي!\n\nالتطبيق يعمل بنجاح ✅',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 22),
),
),
),
);
}
}
