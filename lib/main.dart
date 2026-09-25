import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
      title: 'TalkGPT',
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

  Future<String> _getPersonalMemory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('personal_memory') ?? '';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    await _saveMessages();

    try {
      final memory = await _getPersonalMemory();
      final fullMessage = memory.isNotEmpty
          ? 'سياق شخصي عن المستخدم: $memory\n\nرسالة المستخدم: $text'
          : text;

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 60);

      final response = await dio.post(
        WORKER_URL,
        data: {'message': fullMessage},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200) {
        final responseBody = response.data.toString();
        final lines = responseBody.split('\n');
        String fullReply = '';
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              final data = jsonDecode(jsonStr);
              final candidates = data['candidates'];
              if (candidates != null && candidates is List && candidates.isNotEmpty) {
                final content = candidates[0]['content'];
                if (content != null) {
                  final parts = content['parts'];
                  if (parts != null && parts is List && parts.isNotEmpty) {
                    final textVal = parts[0]['text'];
                    if (textVal != null) {
                      fullReply += textVal.toString();
                    }
                  }
                }
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
          _messages.add({'role': 'assistant', 'content': 'خطأ: ${response.statusCode}'});
        });
        await _saveMessages();
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'خطأ: $e'});
      });
      await _saveMessages();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearChat() async {
    setState(() => _messages.clear());
    await _saveMessages();
  }

  Future<void> _openMemoryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMemory = prefs.getString('personal_memory') ?? '';
    final memoryController = TextEditingController(text: currentMemory);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('الذاكرة الشخصية', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل معلوماتك الشخصية (الاسم، الدراسة، الاهتمامات...).\nسيتم إرسالها مع كل رسالة.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoryController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: اسمي أحمد، أدرس الهندسة في جامعة دمشق...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('personal_memory', memoryController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ الذاكرة الشخصية ✅')),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalkGPT'),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213E),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'الذاكرة الشخصية',
            onPressed: _openMemoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف الدردشة',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF16213E),
                  title: const Text('حذف الدردشة', style: TextStyle(color: Colors.white)),
                  content: const Text('هل تريد حذف كل الرسائل؟', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearChat();
                      },
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
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
                        'مرحباً بك في TalkGPT!\n\nاكتب رسالتك للبدء.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                    ),
                  )
                : ListView.builder(
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
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
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
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
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
