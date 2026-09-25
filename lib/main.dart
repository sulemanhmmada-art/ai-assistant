import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== الشاشة الرئيسية (قائمة المحادثات) ====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _conversations = [];
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('font_size') ?? 14.0;
    });
  }

  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('conversations');
    if (saved != null) {
      final List<dynamic> list = jsonDecode(saved);
      setState(() {
        _conversations = list.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversations', jsonEncode(_conversations));
  }

  Future<void> _createNewConversation() async {
    final newConv = {
      'id': const Uuid().v4(),
      'title': 'محادثة جديدة',
      'messages': <Map<String, String>>[],
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _conversations.insert(0, newConv);
    });
    await _saveConversations();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversation: newConv,
          fontSize: _fontSize,
          onUpdate: _loadConversations,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  Future<void> _deleteConversation(String id) async {
    setState(() {
      _conversations.removeWhere((c) => c['id'] == id);
    });
    await _saveConversations();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(fontSize: _fontSize)),
    );
    if (result != null) {
      setState(() {
        _fontSize = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalkGPT', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white24),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد محادثات بعد',
                      style: TextStyle(fontSize: 20, color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'اضغط + لبدء محادثة جديدة',
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                final messages = conv['messages'] as List<dynamic>? ?? [];
                final lastMessage = messages.isNotEmpty
                    ? messages.last['content']?.toString() ?? ''
                    : 'محادثة فارغة';

                return Card(
                  color: const Color(0xFF16213E),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0F3460),
                      child: Icon(Icons.chat, color: Colors.blue),
                    ),
                    title: Text(
                      conv['title'] ?? 'محادثة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      lastMessage,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF16213E),
                            title: const Text('حذف المحادثة', style: TextStyle(color: Colors.white)),
                            content: const Text('هل تريد حذف هذه المحادثة؟', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('إلغاء'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteConversation(conv['id']);
                                },
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversation: conv,
                            fontSize: _fontSize,
                            onUpdate: _loadConversations,
                          ),
                        ),
                      ).then((_) => _loadConversations());
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ==================== شاشة الدردشة ====================

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final double fontSize;
  final VoidCallback onUpdate;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.fontSize,
    required this.onUpdate,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  static const String WORKER_URL = 'https://gemini-proxy.sulemanhmmada.workers.dev/';

  @override
  void initState() {
    super.initState();
    _messages = List<Map<String, dynamic>>.from(widget.conversation['messages'] ?? []);
  }

  Future<void> _saveCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('conversations');
    if (saved != null) {
      final List<dynamic> list = jsonDecode(saved);
      final convs = list.map((e) => Map<String, dynamic>.from(e)).toList();
      for (var c in convs) {
        if (c['id'] == widget.conversation['id']) {
          c['messages'] = _messages;
          c['title'] = _messages.isNotEmpty
              ? (_messages.first['content'] ?? 'محادثة').toString().substring(
                  0,
                  (_messages.first['content'] ?? 'محادثة').toString().length > 30
                      ? 30
                      : (_messages.first['content'] ?? 'محادثة').toString().length,
                )
              : 'محادثة جديدة';
        }
      }
      await prefs.setString('conversations', jsonEncode(convs));
      widget.onUpdate();
    }
  }

  Future<String> _getPersonalMemory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('personal_memory') ?? '';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    await _saveCurrentConversation();

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
        await _saveCurrentConversation();
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'خطأ: ${response.statusCode}'});
        });
        await _saveCurrentConversation();
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'خطأ: $e'});
      });
      await _saveCurrentConversation();
    } finally {
      setState(() => _isLoading = false);
    }
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
              'أدخل معلوماتك الشخصية. سيتم إرسالها مع كل رسالة.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoryController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: اسمي أحمد، أدرس الهندسة...',
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
              if (mounted) Navigator.pop(context);
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
        title: Text(
          widget.conversation['title'] ?? 'TalkGPT',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'الذاكرة الشخصية',
            onPressed: _openMemoryDialog,
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
                            style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, maxHeight: 150),
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== شاشة الإعدادات ====================

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  const SettingsScreen({super.key, required this.fontSize});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  Future<void> _clearAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('conversations');
    if (!mounted) return;
    Navigator.pop(context, _fontSize);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _sectionTitle('الخط'),
          ListTile(
            title: const Text('حجم الخط', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              '${_fontSize.toInt()} نقطة',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('A', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 10,
                    max: 24,
                    divisions: 14,
                    label: '${_fontSize.toInt()}',
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                      _saveFontSize(value);
                    },
                  ),
                ),
                const Text('A', style: TextStyle(color: Colors.white, fontSize: 22)),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          _sectionTitle('البيانات'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('حذف جميع المحادثات', style: TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF16213E),
                  title: const Text('تأكيد', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'سيتم حذف جميع المحادثات نهائياً. هل أنت متأكد؟',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _clearAllConversations();
                      },
                      child: const Text('حذف الكل'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white24),
          _sectionTitle('حول'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blue),
            title: Text('TalkGPT', style: TextStyle(color: Colors.white)),
            subtitle: Text('الإصدار 2.0.0', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
