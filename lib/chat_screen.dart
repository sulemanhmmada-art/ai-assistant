import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'memory_service.dart';
import 'settings_screen.dart';
import 'snake_game.dart';
import 'background_widgets.dart';

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
  final FocusNode _inputFocus = FocusNode();
  late AnimationController _dotsController;
  late AnimationController _glowController;
  late AnimationController _sendController;
  List<Map<String, dynamic>> _conversations = [];
  String? _currentConversationId;
  bool _isLoading = false;
  XFile? _pendingImage;
  Uint8List? _pendingImageBytes;
  String? _pendingImageBase64;
  bool _isUploadingImage = false;
  bool _imageUploadFailed = false;
  String _selectedModel = 'auto';
  String _backgroundType = 'particles';

  static const String WORKER_URL = 'https://gemini-proxy.sulemanhmmada.workers.dev/';
  static const String IMAGE_WORKER_URL = 'https://image-proxy.sulemanhmmada.workers.dev/';

  bool get _isArabic => widget.locale.languageCode == 'ar';

  String get _newChatText => _isArabic ? 'محادثة جديدة' : 'New Chat';
  String get _welcomeText => _isArabic
      ? 'مرحباً بك في TalkGPT!\n\nاكتب رسالتك للبدء.'
      : 'Welcome to TalkGPT!\n\nType your message to start.';
  String get _hintText => _isArabic ? 'اكتب رسالتك...' : 'Type your message...';
  String get _settingsText => _isArabic ? 'الإعدادات' : 'Settings';
  String get _copyText => _isArabic ? 'نسخ' : 'Copy';
  String get _retryText => _isArabic ? 'إعادة المحاولة' : 'Retry';
  String get _copiedText => _isArabic ? 'تم النسخ ✅' : 'Copied ✅';
  String get _noConversationsText => _isArabic ? 'لا توجد محادثات' : 'No conversations';

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _sendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadAll();
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  Future<void> _loadAll() async {
    _backgroundType = await MemoryService.getBackgroundType();
    await _loadConversations();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _glowController.dispose();
    _sendController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
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
    if (text.isEmpty && _pendingImage == null) return;

    if (_currentConversationId == null) {
      await _createNewConversation();
    }

    if (_pendingImage != null && _pendingImageBase64 == null) return;

    if (text.toLowerCase() == 'suleman') {
      _controller.clear();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SnakeGame()),
      );
      return;
    }

    _sendController.forward().then((_) => _sendController.reverse());

    final messages = _currentMessages;

    if (_pendingImage != null && _pendingImageBase64 != null) {
      messages.add({
        'role': 'user',
        'content': text,
        'image_input': _pendingImageBase64,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      await MemoryService.extractFacts(text, widget.password);
      messages.add({
        'role': 'user',
        'content': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    setState(() {
      _isLoading = true;
      _pendingImage = null;
      _pendingImageBytes = null;
      _pendingImageBase64 = null;
      _imageUploadFailed = false;
    });
    _controller.clear();

    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = messages;
        if (messages.length == 1) {
          c['title'] = text.isNotEmpty
              ? (text.length > 30 ? text.substring(0, 30) : text)
              : (_isArabic ? 'صورة' : 'Image');
        }
      }
    }
    await _saveConversations();
    _scrollToBottom();

    try {
      if (messages.last['image_input'] != null) {
        await _analyzeImageRequest(
          messages.last['image_input'] as String,
          text,
        );
        return;
      }

      final memory = await MemoryService.getMemoryAsText(widget.password);
      final fullMessage = memory.isNotEmpty ? '$memory\n\nرسالة المستخدم: $text' : text;

      final allMessages = _currentMessages;
      final historyEnd = allMessages.length > 1 ? allMessages.length - 1 : 0;
      final historyStart = historyEnd > 10 ? historyEnd - 10 : 0;
      final history = historyEnd > 0
          ? allMessages.sublist(historyStart, historyEnd)
          : <Map<String, dynamic>>[];

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 90);

      final response = await dio.post(
        WORKER_URL,
        data: {
          'message': fullMessage,
          'language': widget.geminiLanguage,
          'history': history,
          'model': _selectedModel,
        },
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

        _addAssistantReply(fullReply);
      }
    } catch (e) {
      _addAssistantReply('خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _addAssistantReply(String content) {
    final newMessages = _currentMessages;
    newMessages.add({
      'role': 'assistant',
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = newMessages;
      }
    }
    _saveConversations();
    setState(() {});
  }

  Future<void> _analyzeImageRequest(String base64Image, String prompt) async {
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
        _addAssistantReply(response.data['reply'] as String);
      } else {
        final errMsg = response.data['error'] ?? 'فشل التحليل';
        _addAssistantReply(errMsg.toString());
      }
    } catch (e) {
      _addAssistantReply('خطأ: $e');
    }
  }

  Future<void> _retryLastMessage() async {
    final messages = _currentMessages;
    if (messages.length < 2) return;

    messages.removeLast();
    final lastUserMsg = messages.isNotEmpty && messages.last['role'] == 'user'
        ? messages.last
        : null;

    if (lastUserMsg == null) return;

    setState(() => _isLoading = true);

    for (var c in _conversations) {
      if (c['id'] == _currentConversationId) {
        c['messages'] = messages;
      }
    }
    await _saveConversations();

    try {
      if (lastUserMsg['image_input'] != null) {
        await _analyzeImageRequest(
          lastUserMsg['image_input'] as String,
          lastUserMsg['content']?.toString() ?? '',
        );
        return;
      }

      final text = lastUserMsg['content']?.toString() ?? '';
      final memory = await MemoryService.getMemoryAsText(widget.password);
      final fullMessage = memory.isNotEmpty ? '$memory\n\nرسالة المستخدم: $text' : text;

      final allMessages = _currentMessages;
      final historyEnd = allMessages.length > 1 ? allMessages.length - 1 : 0;
      final historyStart = historyEnd > 10 ? historyEnd - 10 : 0;
      final history = historyEnd > 0
          ? allMessages.sublist(historyStart, historyEnd)
          : <Map<String, dynamic>>[];

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 90);

      final response = await dio.post(
        WORKER_URL,
        data: {
          'message': fullMessage,
          'language': widget.geminiLanguage,
          'history': history,
          'model': _selectedModel,
        },
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
        if (fullReply.isEmpty) fullReply = _isArabic ? 'عذراً.' : 'Sorry.';
        _addAssistantReply(fullReply);
      }
    } catch (e) {
      _addAssistantReply('خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;
    await _stagePendingImage(picked);
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;
    await _stagePendingImage(picked);
  }

  Future<void> _stagePendingImage(XFile picked) async {
    setState(() {
      _pendingImage = picked;
      _isUploadingImage = true;
      _imageUploadFailed = false;
      _pendingImageBytes = null;
      _pendingImageBase64 = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageBase64 = base64Image;
        _isUploadingImage = false;
        _imageUploadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        _imageUploadFailed = true;
      });
    }
  }

  Future<void> _retryImageUpload() async {
    if (_pendingImage == null) return;
    await _stagePendingImage(_pendingImage!);
  }

  void _removePendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageBytes = null;
      _pendingImageBase64 = null;
      _isUploadingImage = false;
      _imageUploadFailed = false;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
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
          selectedModel: _selectedModel,
        ),
      ),
    );
    if (result != null && result is Map) {
      if (result['model'] != null) {
        setState(() {
          _selectedModel = result['model'] as String;
        });
      }
      if (result['background'] != null) {
        setState(() {
          _backgroundType = result['background'] as String;
        });
      }
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
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                  const Color(0xFF2E1A4A).withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(color: const Color(0xFF764ba2).withValues(alpha: 0.4)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
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
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF764ba2).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.camera_alt, color: Color(0xFF764ba2)),
                    ),
                    title: Text(
                      _isArabic ? 'الكاميرا' : 'Camera',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10A37F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library, color: Color(0xFF10A37F)),
                    ),
                    title: Text(
                      _isArabic ? 'الاستديو' : 'Gallery',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
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
        resizeToAvoidBottomInset: true,
        body: AppBackground(
          type: _backgroundType,
          child: SafeArea(
            child: Column(
              children: [
                _buildGlassAppBar(messages),
                Expanded(
                  child: _currentConversationId == null
                      ? _buildWelcomeScreen()
                      : ListView.builder(
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
                _buildGlassInputBar(),
              ],
            ),
          ),
        ),
        drawer: _buildGlassDrawer(),
      ),
    );
  }

  Widget _buildGlassAppBar(List<Map<String, dynamic>> messages) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF764ba2).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Text(
                  _currentConversation?['title'] ?? 'TalkGPT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_currentConversationId != null)
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF764ba2)),
                  tooltip: _newChatText,
                  onPressed: _createNewConversation,
                ),
            ],
          ),
        ),
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
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF764ba2).withValues(
                          alpha: 0.3 + (_glowController.value * 0.4),
                        ),
                        blurRadius: 40 + (_glowController.value * 30),
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, size: 70, color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'TalkGPT',
              style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _welcomeText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E1A4A).withValues(alpha: 0.95),
                  const Color(0xFF0E1116).withValues(alpha: 0.95),
                ],
              ),
              border: Border(
                right: BorderSide(color: const Color(0xFF764ba2).withValues(alpha: 0.4)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'TalkGPT',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF764ba2).withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createNewConversation();
                        },
                        icon: const Icon(Icons.add),
                        label: Text(_newChatText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: const Color(0xFF764ba2).withValues(alpha: 0.3)),
                  Expanded(
                    child: _conversations.isEmpty
                        ? Center(
                            child: Text(
                              _noConversationsText,
                              style: const TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final isSelected = conv['id'] == _currentConversationId;
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xFF764ba2).withValues(alpha: 0.2),
                                leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
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
                  Divider(color: const Color(0xFF764ba2).withValues(alpha: 0.3)),
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
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, int index) {
    final hasImage = msg['image_input'] != null;
    final isLastAssistant = !isUser && index == _currentMessages.length - 1;

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser
              ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
              : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF764ba2).withValues(alpha: 0.6),
                            const Color(0xFF5B3A8E).withValues(alpha: 0.4),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.05),
                            const Color(0xFF10A37F).withValues(alpha: 0.08),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUser
                        ? const Color(0xFF764ba2).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? const Color(0xFF764ba2).withValues(alpha: 0.3)
                          : const Color(0xFF10A37F).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImageContent(msg['image_input'] as String),
                      ),
                    if (hasImage && (msg['content']?.toString().isNotEmpty ?? false))
                      const SizedBox(height: 8),
                    if (!hasImage || (msg['content']?.toString().isNotEmpty ?? false))
                      isUser
                          ? SelectableText(
                              msg['content']?.toString() ?? '',
                              style: TextStyle(color: Colors.white, fontSize: widget.fontSize, height: 1.5),
                              textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                            )
                          : MarkdownBody(
                              data: msg['content']?.toString() ?? '',
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.fontSize,
                                  height: 1.6,
                                ),
                                h1: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.fontSize + 8,
                                  fontWeight: FontWeight.bold,
                                  height: 1.8,
                                ),
                                h2: TextStyle(
                                  color: const Color(0xFF764ba2),
                                  fontSize: widget.fontSize + 5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.8,
                                ),
                                h3: TextStyle(
                                  color: const Color(0xFF10A37F),
                                  fontSize: widget.fontSize + 3,
                                  fontWeight: FontWeight.w600,
                                  height: 1.6,
                                ),
                                listBullet: TextStyle(
                                  color: const Color(0xFF764ba2),
                                  fontSize: widget.fontSize,
                                ),
                                code: TextStyle(
                                  color: const Color(0xFF10A37F),
                                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                                  fontFamily: 'monospace',
                                  fontSize: widget.fontSize - 1,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF764ba2).withValues(alpha: 0.3),
                                  ),
                                ),
                                blockquoteDecoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: const Border(left: BorderSide(color: Color(0xFF764ba2), width: 3)),
                                ),
                                tableBorder: TableBorder.all(color: Colors.white24),
                                tableCellsPadding: const EdgeInsets.all(8),
                                strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                em: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
                              ),
                            ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: isUser
              ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
              : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 18),
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'copy') {
                await Clipboard.setData(ClipboardData(text: msg['content']?.toString() ?? ''));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_copiedText),
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF764ba2),
                    ),
                  );
                }
              } else if (value == 'retry' && isLastAssistant) {
                _retryLastMessage();
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
              if (isLastAssistant)
                PopupMenuItem(
                  value: 'retry',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Color(0xFF764ba2), size: 18),
                      const SizedBox(width: 8),
                      Text(_retryText, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(String base64Str) {
    try {
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white54, size: 40),
        ),
      );
    }
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF764ba2).withValues(alpha: 0.15 + (_glowController.value * 0.15)),
                      const Color(0xFF10A37F).withValues(alpha: 0.08 + (_glowController.value * 0.12)),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF764ba2).withValues(alpha: 0.4 + (_glowController.value * 0.5)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF764ba2).withValues(alpha: 0.2 + (_glowController.value * 0.35)),
                      blurRadius: 15 + (_glowController.value * 20),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _dotsController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) => _buildFlowingDot(i)),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlowingDot(int index) {
    final t = _dotsController.value;
    final phase = (t + (index * 0.33)) % 1.0;
    final yOffset = -8 * (1 - (2 * (phase - 0.5)).abs()) * (phase < 0.5 ? 1 : -1);
    final opacity = 0.4 + (0.6 * (1 - (phase - 0.5).abs() * 2));
    final scale = 0.8 + (0.4 * (1 - (phase - 0.5).abs() * 2));

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 11,
          width: 11,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF764ba2).withValues(alpha: opacity),
                const Color(0xFF10A37F).withValues(alpha: opacity),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF764ba2).withValues(alpha: opacity * 0.8),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border(
              top: BorderSide(color: const Color(0xFF764ba2).withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildPendingPreview(),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: _removePendingImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF764ba2).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white, size: 26),
                      onPressed: _showAttachmentOptions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF764ba2).withValues(alpha: 0.3),
                            ),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48, maxHeight: 150),
                            child: TextField(
                              controller: _controller,
                              focusNode: _inputFocus,
                              style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
                              maxLines: null,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                              decoration: InputDecoration(
                                hintText: _hintText,
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 0.85).animate(
                      CurvedAnimation(parent: _sendController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF764ba2).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 24),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPreview() {
    if (_isUploadingImage) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF764ba2),
            ),
          ),
        ),
      );
    }
    if (_imageUploadFailed) {
      return GestureDetector(
        onTap: _retryImageUpload,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF5576C), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.refresh,
              color: Color(0xFFF5576C),
              size: 40,
            ),
          ),
        ),
      );
    }
    if (_pendingImageBytes != null) {
      return Image.memory(
        _pendingImageBytes!,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 100,
            height: 100,
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 30),
            ),
          );
        },
      );
    }
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
