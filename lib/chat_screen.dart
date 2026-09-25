import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;
  final Function(Locale, double, String) onSettingsChanged;

  const ChatScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
    required this.onSettingsChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _conversations = [];
  String? _currentConversationId;
  bool _isLoading = false;

  static const String WORKER_URL = 'https://gemini-proxy.sulemanhmmada.workers.dev/';
  static const String IMAGE_WORKER_URL = 'https://image-proxy.sulemanhmmada.workers.dev/';

  bool get _isArabic => widget.locale.languageCode == 'ar';

  String get _newChatText => _isArabic ? 'محادثة جديدة' : 'New Chat';
  String get _welcomeText => _isArabic
      ? 'مرحباً بك في TalkGPT!\n\nاضغط + لبدء محادثة جديدة.'
      : 'Welcome to TalkGPT!\n\nTap + to start a new chat.';
  String get _hintText => _isArabic ? 'اكتب رسالتك...' : 'Type your message...';
  String get _settingsText => _isArabic ? 'الإعدادات' : 'Settings';
  String get _memoryText => _isArabic ? 'الذاكرة الشخصية' : 'Personal Memory';
  String get _cancelText => _isArabic ? 'إلغاء' : 'Cancel';
  String get _saveText => _isArabic ? 'حفظ' : 'Save';
  String get _copyText => _isArabic ? 'نسخ' : 'Copy';
  String get _copiedText => _isArabic ? 'تم النسخ ✅' : 'Copied ✅';
  String get _noConversationsText => _isArabic ? 'لا توجد محادثات' : 'No conversations';
  String get _memoryHint => _isArabic
      ? 'مثال: اسمي أحمد، أدرس الهندسة...'
      : 'e.g., My name is Ahmed, I study engineering...';
  String get _memoryDescription => _isArabic
      ? 'سيتم إرسال هذه المعلومات مع كل رسالة.'
      : 'This will be sent with every message.';
  String get _generateImageText => _isArabic ? 'توليد صورة' : 'Generate Image';
  String get _imageDescriptionHint => _isArabic
      ? 'مثال: قطة تلعب في الحديقة، رسم فني'
      : 'e.g., A cat playing in the garden, artistic style';
  String get _generateText => _isArabic ? 'توليد' : 'Generate';
  String get _generatingText => _isArabic ? 'جاري التوليد...' : 'Generating...';
  String get _imageGeneratedText => _isArabic ? '🎨 صورة مولّدة' : '🎨 Generated image';
  String get _saveToGalleryText => _isArabic ? 'حفظ في المعرض' : 'Save to Gallery';
  String get _savedText => _isArabic ? 'تم الحفظ في المعرض ✅' : 'Saved to gallery ✅';
  String get _imageErrorText => _isArabic ? 'فشل توليد الصورة' : 'Failed to generate image';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('conversations');
    if (saved != null) {
      final List<dynamic> list = jsonDecode(saved);
      setState(() {
        _conversations = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversations', jsonEncode(_conversations));
  }

  Map<String, dynamic>? get _currentConversation {
    if (_currentConversationId == null) return null;
    for (final c in _conversations) {
      if (c['id'] == _currentConversationId) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> get _currentMessages {
    final conv = _currentConversation;
    if (conv == null) return [];
    final messages = conv['messages'];
    if (messages == null) return [];
    return List<Map<String, dynamic>>.from(
      (messages as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> _createNewConversation() async {
    final newConv = <String, dynamic>{
      'id': const Uuid().v4(),
      'title': _newChatText,
      'messages': <Map<String, dynamic>>[],
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _conversations.insert(0, newConv);
      _currentConversationId = newConv['id'] as String;
    });
    await _saveConversations();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectConversation(String id) async {
    setState(() {
      _currentConversationId = id;
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteConversation(String id) async {
    setState(() {
      _conversations.removeWhere((c) => c['id'] == id);
      if (_currentConversationId == id) {
        _currentConversationId = null;
      }
    });
    await _saveConversations();
  }

  Future<String> _getPersonalMemory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('personal_memory') ?? '';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentConversationId == null) return;

    final messages = _currentMessages;
    messages.add({
      'role': 'user',
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    setState(() {
      _isLoading = true;
    });
    _controller.clear();

    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = messages;
        if (messages.length == 1) {
          c['title'] = text.length > 30 ? text.substring(0, 30) : text;
        }
      }
    }
    await _saveConversations();
    _scrollToBottom();

    try {
      final memory = await _getPersonalMemory();
      final fullMessage = memory.isNotEmpty
          ? 'سياق شخصي عن المستخدم: $memory\n\nرسالة المستخدم: $text'
          : text;

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 90);

      final response = await dio.post(
        WORKER_URL,
        data: {'message': fullMessage, 'language': widget.geminiLanguage},
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

        if (fullReply.isEmpty) {
          fullReply = _isArabic ? 'عذراً، لم أستطع توليد رد.' : 'Sorry, no reply.';
        }

        final newMessages = _currentMessages;
        newMessages.add({
          'role': 'assistant',
          'content': fullReply,
          'timestamp': DateTime.now().toIso8601String(),
        });
        for (var c in _conversations) {
          if (c['id'] == _currentConversationId) {
            c['messages'] = newMessages;
          }
        }
        await _saveConversations();
        setState(() {});
      }
    } catch (e) {
      final errMessages = _currentMessages;
      errMessages.add({'role': 'assistant', 'content': 'خطأ: $e'});
      for (var c in _conversations) {
        if (c['id'] == _currentConversationId) {
          c['messages'] = errMessages;
        }
      }
      await _saveConversations();
      setState(() {});
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _generateImage(String prompt) async {
    if (prompt.trim().isEmpty || _currentConversationId == null) return;

    final messages = _currentMessages;
    messages.add({
      'role': 'user',
      'content': '🎨 $_generateImageText: $prompt',
      'timestamp': DateTime.now().toIso8601String(),
    });

    setState(() {
      _isLoading = true;
    });

    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = messages;
        if (messages.length == 1) {
          c['title'] = prompt.length > 30 ? prompt.substring(0, 30) : prompt;
        }
      }
    }
    await _saveConversations();
    _scrollToBottom();

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 120);

      final response = await dio.post(
        IMAGE_WORKER_URL,
        data: {'prompt': prompt},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final base64Image = response.data['image'] as String;
        final newMessages = _currentMessages;
        newMessages.add({
          'role': 'assistant',
          'content': _imageGeneratedText,
          'image': base64Image,
          'timestamp': DateTime.now().toIso8601String(),
        });
        for (var c in _conversations) {
          if (c['id'] == _currentConversationId) {
            c['messages'] = newMessages;
          }
        }
        await _saveConversations();
        setState(() {});
      } else {
        final errMessages = _currentMessages;
        errMessages.add({
          'role': 'assistant',
          'content': '$_imageErrorText: ${response.statusCode}',
        });
        for (var c in _conversations) {
          if (c['id'] == _currentConversationId) {
            c['messages'] = errMessages;
          }
        }
        await _saveConversations();
        setState(() {});
      }
    } catch (e) {
      final errMessages = _currentMessages;
      errMessages.add({'role': 'assistant', 'content': '$_imageErrorText: $e'});
      for (var c in _conversations) {
        if (c['id'] == _currentConversationId) {
          c['messages'] = errMessages;
        }
      }
      await _saveConversations();
      setState(() {});
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

  Future<void> _saveImageToGallery(String base64Image) async {
    try {
      final bytes = base64Decode(base64Image);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/talkgpt_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_savedText), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _showImageDialog() async {
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _generateImageText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: promptController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _imageDescriptionHint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              final prompt = promptController.text.trim();
              if (prompt.isNotEmpty) {
                Navigator.pop(context);
                _generateImage(prompt);
              }
            },
            child: Text(_generateText),
          ),
        ],
      ),
    );
  }

  Future<void> _openMemoryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMemory = prefs.getString('personal_memory') ?? '';
    final memoryController = TextEditingController(text: currentMemory);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _memoryText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _memoryDescription,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memoryController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _memoryHint,
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
            child: Text(_cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              await prefs.setString('personal_memory', memoryController.text);
              if (mounted) Navigator.pop(context);
            },
            child: Text(_saveText),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          fontSize: widget.fontSize,
          geminiLanguage: widget.geminiLanguage,
          locale: widget.locale,
        ),
      ),
    );
    if (result != null && result is Map) {
      widget.onSettingsChanged(
        result['locale'] as Locale,
        result['fontSize'] as double,
        result['geminiLanguage'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _currentMessages;

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            _currentConversation?['title'] ?? 'TalkGPT',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.psychology),
              tooltip: _memoryText,
              onPressed: _openMemoryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: _settingsText,
              onPressed: _openSettings,
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _currentConversationId == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 100,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _welcomeText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && _isLoading) {
                          return _buildTypingIndicator();
                        }
                        final msg = messages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildMessageBubble(msg, isUser);
                      },
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
        floatingActionButton: _currentConversationId == null
            ? FloatingActionButton.extended(
                onPressed: _createNewConversation,
                backgroundColor: Colors.blue,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  _newChatText,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF16213E),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.smart_toy, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'TalkGPT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _createNewConversation,
                icon: const Icon(Icons.add),
                label: Text(_newChatText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: _conversations.isEmpty
                  ? Center(
                      child: Text(
                        _noConversationsText,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isSelected = conv['id'] == _currentConversationId;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.blue.withValues(alpha: 0.2),
                          leading: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white70,
                          ),
                          title: Text(
                            conv['title']?.toString() ?? _newChatText,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _deleteConversation(conv['id'] as String),
                          ),
                          onTap: () => _selectConversation(conv['id'] as String),
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: Text(
                _settingsText,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser) {
    final hasImage = msg['image'] != null;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF16213E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: Text(
                    _copyText,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_copiedText),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.green),
                    title: Text(
                      _saveToGalleryText,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _saveImageToGallery(msg['image'] as String);
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: Align(
        alignment: isUser
            ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
            : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: isUser ? Colors.blue[700] : const Color(0xFF0F3460),
            borderRadius: BorderRadius.circular(18),
          ),
          child: hasImage
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['content']?.toString() ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(msg['image'] as String),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(20),
                          child: const Text(
                            'فشل عرض الصورة',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط مطولاً للحفظ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                )
              : SelectableText(
                  msg['content']?.toString() ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.fontSize,
                    height: 1.5,
                  ),
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _buildDot(i)),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 200)),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.6 + (index * 0.2)),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
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
                textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: _hintText,
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.image, color: Colors.purple),
            tooltip: _generateImageText,
            onPressed: _currentConversationId != null ? _showImageDialog : null,
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
