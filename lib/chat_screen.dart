import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'memory_service.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;
  final String password;
  final Function(Locale, double, String) onSettingsChanged;

  const ChatScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
    required this.password,
    required this.onSettingsChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _dotsController;
  late AnimationController _glowController;
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
  String get _cancelText => _isArabic ? 'إلغاء' : 'Cancel';
  String get _copyText => _isArabic ? 'نسخ' : 'Copy';
  String get _copiedText => _isArabic ? 'تم النسخ ✅' : 'Copied ✅';
  String get _noConversationsText => _isArabic ? 'لا توجد محادثات' : 'No conversations';
  String get _imagePromptHint => _isArabic
      ? 'اكتب سؤالك عن الصورة (اختياري)...'
      : 'Ask about the image (optional)...';

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadConversations();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _glowController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final convs = await MemoryService.loadConversations(widget.password);
    setState(() {
      _conversations = convs;
    });
  }

  Future<void> _saveConversations() async {
    await MemoryService.saveConversations(_conversations, widget.password);
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
  }

  Future<void> _selectConversation(String id) async {
    setState(() {
      _currentConversationId = id;
    });
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentConversationId == null) return;

    await MemoryService.extractFacts(text, widget.password);

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
      final memory = await MemoryService.getMemoryAsText(widget.password);
      final fullMessage = memory.isNotEmpty
          ? '$memory\n\nرسالة المستخدم: $text'
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

  // ============ تحليل الصور ============
  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _processImage(picked);
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _processImage(picked);
  }

  Future<void> _processImage(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);

    if (!mounted) return;

    final controller = TextEditingController();
    final userPrompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isArabic ? 'تحليل الصورة' : 'Analyze Image',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _imagePromptHint,
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
            onPressed: () => Navigator.pop(context, ''),
            child: Text(_cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(_isArabic ? 'تحليل' : 'Analyze'),
          ),
        ],
      ),
    );

    if (userPrompt == null) return;
    await _analyzeImage(base64Image, userPrompt);
  }

  Future<void> _analyzeImage(String base64Image, String prompt) async {
    if (_currentConversationId == null) {
      await _createNewConversation();
    }

    final messages = _currentMessages;
    messages.add({
      'role': 'user',
      'content': prompt.isEmpty
          ? (_isArabic ? '🖼️ حلل هذه الصورة' : '🖼️ Analyze this image')
          : '🖼️ $prompt',
      'image_input': base64Image,
      'timestamp': DateTime.now().toIso8601String(),
    });

    setState(() {
      _isLoading = true;
    });

    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = messages;
        if (messages.length == 1) {
          c['title'] = _isArabic ? 'تحليل صورة' : 'Image analysis';
        }
      }
    }
    await _saveConversations();
    _scrollToBottom();

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 120);
      dio.options.validateStatus = (status) => status != null && status < 500;

      final response = await dio.post(
        IMAGE_WORKER_URL,
        data: {
          'prompt': prompt,
          'image': base64Image,
          'fileType': 'image',
          'language': widget.geminiLanguage,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final reply = response.data['reply'] as String;
        final newMessages = _currentMessages;
        newMessages.add({
          'role': 'assistant',
          'content': reply,
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
        final errMsg = response.data['error'] ?? 'فشل التحليل';
        final errMessages = _currentMessages;
        errMessages.add({'role': 'assistant', 'content': errMsg.toString()});
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

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          fontSize: widget.fontSize,
          geminiLanguage: widget.geminiLanguage,
          locale: widget.locale,
          password: widget.password,
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF10A37F)),
              title: Text(
                _isArabic ? 'الكاميرا' : 'Camera',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF10A37F)),
              title: Text(
                _isArabic ? 'الاستديو' : 'Gallery',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _currentMessages;

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1116),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0E1116),
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            _currentConversation?['title'] ?? 'TalkGPT',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          actions: const [],
        ),
        drawer: _buildDrawer(),
        body: _currentConversationId == null
            ? _buildWelcomeScreen()
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && _isLoading) {
                          return _buildTypingIndicator();
                        }
                        final msg = messages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildMessageBubble(msg, isUser, index);
                      },
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
        floatingActionButton: _currentConversationId == null
            ? FloatingActionButton.extended(
                onPressed: _createNewConversation,
                backgroundColor: const Color(0xFF10A37F),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(_newChatText, style: const TextStyle(color: Colors.white)),
              )
            : null,
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 60, color: Color(0xFF10A37F)),
            ),
            const SizedBox(height: 24),
            const Text(
              'TalkGPT',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _welcomeText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white60, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0E1116),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10A37F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'TalkGPT',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _createNewConversation();
                },
                icon: const Icon(Icons.add),
                label: Text(_newChatText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10A37F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            Expanded(
              child: _conversations.isEmpty
                  ? Center(
                      child: Text(_noConversationsText, style: const TextStyle(color: Colors.white38)),
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isSelected = conv['id'] == _currentConversationId;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF10A37F).withValues(alpha: 0.15),
                          leading: const Icon(Icons.chat_bubble_outline, color: Colors.white60, size: 20),
                          title: Text(
                            conv['title']?.toString() ?? _newChatText,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteConversation(conv['id'] as String),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _selectConversation(conv['id'] as String);
                          },
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: Text(_settingsText, style: const TextStyle(color: Colors.white)),
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

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, int index) {
    final hasImage = msg['image_input'] != null;

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser
              ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
              : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF10A37F) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(msg['image_input'] as String),
                      fit: BoxFit.cover,
                      height: 200,
                    ),
                  ),
                if (hasImage) const SizedBox(height: 8),
                SelectableText(
                  msg['content']?.toString() ?? '',
                  style: TextStyle(color: Colors.white, fontSize: widget.fontSize, height: 1.5),
                  textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: isUser
              ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
              : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
            color: const Color(0xFF1E1E1E),
            onSelected: (value) async {
              if (value == 'copy') {
                await Clipboard.setData(ClipboardData(text: msg['content']?.toString() ?? ''));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_copiedText), duration: const Duration(seconds: 1)),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(_copyText, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF10A37F).withValues(alpha: 0.3 + (_glowController.value * 0.5)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10A37F).withValues(alpha: 0.15 + (_glowController.value * 0.35)),
                  blurRadius: 10 + (_glowController.value * 15),
                  spreadRadius: 1 + (_glowController.value * 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) => _buildDot(i)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDot(int index) {
    final t = _dotsController.value;
    final offset = (t * 3) % 3;
    final isActive = offset >= index && offset < index + 1;
    final scale = isActive ? 1.4 : 1.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 10,
        width: 10,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF10A37F) : const Color(0xFF10A37F).withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF0E1116),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 28),
              onPressed: _showAttachmentOptions,
              tooltip: _isArabic ? 'إرفاق' : 'Attach',
            ),
            const SizedBox(width: 4),
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
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF10A37F)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
