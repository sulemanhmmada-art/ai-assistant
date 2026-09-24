import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
bool _isLoading = false;

static const String WORKER_URL = 'https://gemini-proxy.sulemanhmmada.workers.dev/';

@override
void initState() {
super.initState();
_loadMessages();
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
'مرحباً! أنا مساعدك الذكي.\nاكتب رسالتك ليبدأ الحديث.',
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
