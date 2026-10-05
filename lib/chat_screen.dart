import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
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
      ? 'مرحباً بك في TalkGPT!\n\nأنا جاهز لمساعدتك اليوم.'
      : 'Welcome to TalkGPT!\n\nI am ready to help you today.';
  String get _hintText => _isArabic ? 'اسأل أي شيء...' : 'Ask anything...';
  String get _settingsText => _isArabic ? 'الإعدادات' : 'Settings';
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
                  const Color(0xFF1E1E2C).withOpacity(0.9),
                  const Color(0xFF0D0E15).withOpacity(0.9),
                ],
              ),
              border: Border.all(color: const Color(0xFF3861FB).withOpacity(0.3)),
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
                        color: const Color(0xFF3861FB).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.camera_alt, color: Color(0xFF3861FB)),
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
                        color: const Color(0xFF00D2FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library, color: Color(0xFF00D2FF)),
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
        backgroundColor: const Color(0xFF08090C), // أسود أعمق يطابق التصميم
        body: Stack(
          children: [
            // خلفية الشاشة الأساسية
            AppBackground(
              type: _backgroundType,
              child: const SizedBox.expand(),
            ),
            
            // إضاءة أزرق كهربائي ساطع في أسفل الشاشة (تطابق التصميم المرجعي)
            Positioned(
              bottom: -100,
              left: 0,
              right: 0,
              height: 350,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2B52FF).withOpacity(0.45),
                      const Color(0xFF001147).withOpacity(0.2),
                      Colors.transparent,
                    ],
                    radius: 0.85,
                  ),
                ),
              ),
            ),

            // واجهة المحادثة الرئيسية
            SafeArea(
              child: Column(
                children: [
                  _buildGlassAppBar(messages),
                  Expanded(
                    child: _currentConversationId == null
                        ? _buildWelcomeScreen()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ],
        ),
        drawer: _buildGlassDrawer(),
      ),
    );
  }

  Widget _buildGlassAppBar(List<Map<String, dynamic>> messages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white70),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Text(
              _currentConversation?['title'] ?? 'TalkGPT',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_currentConversationId != null)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              tooltip: _newChatText,
              onPressed: _createNewConversation,
            )
          else
            const SizedBox(width: 48),
        ],
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
            AiOrbWidget(
              state: _isLoading ? OrbState.thinking : OrbState.idle,
              size: 180,
            ),
            const SizedBox(height: 36),
            const Text(
              'TalkGPT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _welcomeText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.white60, height: 1.5),
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
                  const Color(0xFF121420).withOpacity(0.95),
                  const Color(0xFF08090C).withOpacity(0.98),
                ],
              ),
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B52FF), Color(0xFF00D2FF)],
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2B52FF), Color(0xFF00D2FF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2B52FF).withOpacity(0.3),
                            blurRadius: 12,
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
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withOpacity(0.1)),
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
                                selectedTileColor: const Color(0xFF2B52FF).withOpacity(0.15),
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
                  Divider(color: Colors.white.withOpacity(0.1)),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser
                ? (_isArabic ? Alignment.centerRight : Alignment.centerLeft)
                : (_isArabic ? Alignment.centerLeft : Alignment.centerRight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF2B52FF).withOpacity(0.25)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isUser
                          ? const Color(0xFF2B52FF).withOpacity(0.5)
                          : Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
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
                            width: double.infinity,
                          ),
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
                                  p: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: widget.fontSize, height: 1.5),
                                ),
                              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiOrbWidget(state: OrbState.thinking, size: 28),
            const SizedBox(width: 10),
            Text(
              _isArabic ? "جاري التفكير..." : "Thinking...",
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// شريط الإدخال العائم المطابق تماماً للتصميم المرجعي (كبسولة زجاجية متوهجة)
  Widget _buildGlassInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161822).withOpacity(0.65),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B52FF).withOpacity(0.25),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // زر إضافة المرفقات (+)
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white70, size: 24),
                  onPressed: _showAttachmentOptions,
                ),

                // حقل النص الرئيسي
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
                    decoration: InputDecoration(
                      hintText: _hintText,
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // أيقونة الصوت المضيئة (أسلوب التصميم المرجعي)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Color(0xFF00D2FF),
                    size: 20,
                  ),
                ),

                // زر الإرسال الإشعاعي
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2B52FF), Color(0xFF00D2FF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
