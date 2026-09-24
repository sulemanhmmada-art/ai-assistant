import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
scaffoldBackgroundColor: const Color(0xFF1A1A2E),
),
home: const ChatScreen(),
locale: const Locale('ar'),
);
}
}

class ChatScreen extends StatefulWidget {
const ChatScreen({super.key});

@override
State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
final TextEditingController _controller = TextEditingController();
final ScrollController _scrollController = ScrollController();
final List<Map<String, String>> _messages = [];
final FlutterTts _flutterTts = FlutterTts();
final stt.SpeechToText _speech = stt.SpeechToText();
bool _isLoading = false;
bool _isListening = false;

// ⚠️ غيّر هذا الرابط إلى رابط Cloudflare Worker الخاص بك
static const String WORKER_URL = 'https://gemini-proxy.suleimanhmmada.workers.dev';

@override
void initState() {
super.initState();
_initTts();
_loadMessages();
}

void _initTts() async {
await _flutterTts.setLanguage('ar-SA');
await _flutterTts.setSpeechRate(0.5);
}

Future<void> _loadMessages() async {
final prefs = await SharedPreferences.getInstance();
final saved = prefs.getString('messages');
if (saved != null) {
final List<dynamic> list = jsonDecode(saved);
setState(() {
_messages.addAll(list.map((e) => Map<String, String>.from(e)));
});
}
}

Future<void> _saveMessages() async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('messages', jsonEncode(_messages));
}

Future<void> _sendMessage(String text) async {
if (text.trim().isEmpty) return;

setState(() {
_messages.add({'role': 'user', 'content': text});
_isLoading = true;
});
_controller.clear();
_scrollToBottom();

try {
final response = await http.post(
Uri.parse(WORKER_URL),
headers: {'Content-Type': 'application/json'},
body: jsonEncode({'message': text}),
);

if (response.statusCode == 200) {
// معالجة Streaming SSE
final lines = response.body.split('\n');
String fullReply = '';
for (final line in lines) {
if (line.startsWith('data: ')) {
try {
final jsonStr = line.substring(6);
final data = jsonDecode(jsonStr);
final parts = data['candidates']?[0]?['content']?['parts'];
if (parts != null && parts.isNotEmpty) {
fullReply += parts[0]['text'] ?? '';
}
} catch (_) {}
}
}

if (fullReply.isEmpty) fullReply = 'عذراً، لم أستطع توليد رد.';

setState(() {
_messages.add({'role': 'assistant', 'content': fullReply});
});
await _saveMessages();
await _flutterTts.speak(fullReply);
} else {
setState(() {
_messages.add({'role': 'assistant', 'content': 'حدث خطأ: latex
{response.statusCode}'}); }); } } catch (e) { setState(() { _messages.add({'role': 'assistant', 'content': 'خطأ في الاتصال: 

e'});
});
} finally {
setState(() => _isLoading = false);
_scrollToBottom();
}
}

void _scrollToBottom() {
Future.delayed(const Duration(milliseconds: 100), () {
if (_scrollController.hasClients) {
_scrollController.animateTo(
_scrollController.position.maxScrollExtent,
duration: const Duration(milliseconds: 300),
curve: Curves.easeOut,
);
}
});
}

Future<void> _toggleListening() async {
if (_isListening) {
await _speech.stop();
setState(() => _isListening = false);
return;
}

bool available = await _speech.initialize();
if (available) {
setState(() => _isListening = true);
await _speech.listen(
onResult: (result) {
_controller.text = result.recognizedWords;
},
localeId: 'ar_SA',
);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('المساعد الذكي'),
centerTitle: true,
backgroundColor: const Color(0xFF16213E),
actions: [
IconButton(
icon: const Icon(Icons.delete_outline),
onPressed: () async {
setState(() => _messages.clear());
await _saveMessages();
},
),
 ],
),
body: Column(
children: [
Expanded(
child: _messages.isEmpty
? const Center(
child: Padding(
padding: EdgeInsets.all(24),
child: Text(
'مرحباً! أنا مساعدك الذكي.\nاكتب أو تحدث ليبدأ الحديث.',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 18, color: Colors.white70),
),
),
)
: ListView.builder(
controller: _scrollController,
padding: const EdgeInsets.all(12),
itemCount: _messages.length,
itemBuilder: (context, index) {
final msg = _messages[index];
final isUser = msg['role'] == 'user';
return Align(
alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
child: Container(
margin: const EdgeInsets.symmetric(vertical: 6),
padding: const EdgeInsets.all(12),
constraints: BoxConstraints(
maxWidth: MediaQuery.of(context).size.width * 0.75,
),
decoration: BoxDecoration(
color: isUser ? Colors.blue[700] : const Color(0xFF0F3460),
borderRadius: BorderRadius.circular(16),
),
child: Text(
msg['content'] ?? '',
style: const TextStyle(color: Colors.white, fontSize: 16),
),
),
);
},
),
),
if (_isLoading)
const Padding(
padding: EdgeInsets.all(8),
child: CircularProgressIndicator(),
),
Container(
padding: const EdgeInsets.all(8),
color: const Color(0xFF16213E),
child: Row(
children: [
IconButton(
icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
color: _isListening ? Colors.red : Colors.white,
onPressed: _toggleListening,
),
Expanded(
child: TextField(
controller: _controller,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: 'اكتب رسالتك...',
hintStyle: const TextStyle(color: Colors.white54),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(24),
borderSide: BorderSide.none,
),
filled: true,
fillColor: const Color(0xFF1A1A2E),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
onSubmitted: _sendMessage,
),
),
IconButton(
icon: const Icon(Icons.send, color: Colors.blue),
onPressed: () => _sendMessage(_controller.text),
),
 ],
),
),
],
),
);
}
}
