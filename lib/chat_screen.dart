import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'background_widgets.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ChatScreen({super.key, required this.onOpenDrawer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  OrbState _orbState = OrbState.idle;

  // اقتراحات البداية السريعة
  final List<Map<String, String>> _quickPrompts = [
    {'title': 'أفكار إبداعية', 'prompt': 'اقترح عليّ 5 أفكار لمشروع ذكاء اصطناعي ناشئ'},
    {'title': 'كتابة محتوى', 'prompt': 'اكتب لي بريدًا إلكترونيًا احترافيًا للارتقاء الوظيفي'},
    {'title': 'تطوير البرمجيات', 'prompt': 'اشرح لي مفهوم الـ Stream في دارت وفلاتر بأسلوب بسيط'},
  ];

  void _sendMessage([String? customText]) {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
      _orbState = OrbState.thinking;
      if (customText == null) _textController.clear();
    });

    _scrollToBottom();

    // محاكاة استجابة السيرفر عبر الـ Proxy
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _orbState = OrbState.speaking;
        _messages.add({
          'sender': 'ai',
          'text': 'هذا رد تجريبي محاكاة للذكاء الاصطناعي عبر الـ Worker الخاص بك! نصك كان: "$text"',
        });
      });
      _scrollToBottom();

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _orbState = OrbState.idle);
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. الشريط العلوي (App Bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                      onPressed: widget.onOpenDrawer,
                    ),
                    const Row(
                      children: [
                        Text(
                          'TalkGPT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.sparkles, color: Color(0xFF00D2FF), size: 18),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 24),
                      onPressed: () {
                        setState(() => _messages.clear());
                      },
                    ),
                  ],
                ),
              ),

              // 2. منطقة المحتوى والرسائل
              Expanded(
                child: _messages.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            AiOrbWidget(state: _orbState, size: 170),
                            const SizedBox(height: 24),
                            const Text(
                              'كيف يمكنني مساعدتك اليوم؟',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اختر إحدى البدايات السريعة أو اكتب سؤالك أدناه',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // كروت الاقتراحات السريعة
                            Column(
                              children: _quickPrompts.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                      child: InkWell(
                                        onTap: () => _sendMessage(item['prompt']),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.1),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.auto_awesome_outlined,
                                                  color: Color(0xFF00D2FF), size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item['prompt']!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Icon(Icons.arrow_forward_ios_rounded,
                                                  color: Colors.white.withOpacity(0.3), size: 14),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['sender'] == 'user';
                          return _buildMessageBubble(msg['text'], isUser);
                        },
                      ),
              ),

              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF00D2FF).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'جاري التفكير...',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // 3. مربع الإدخال الزجاجي العصري (Capsule Glass Input Bar)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D2FF)),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'اسأل أي شيء...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.mic_none_rounded, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _sendMessage(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF00D2FF)],
                                ),
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
        ),
      ),
    );
  }

  // بناء فقاعات المحادثة وأدوات التحكم
  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00D2FF).withOpacity(0.2),
                    border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.sparkles, color: Color(0xFF00D2FF), size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF6C5CE7)],
                          )
                        : null,
                    color: isUser ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // أزرار التحكم تحت رسالة الذكاء الاصطناعي
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 36, top: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ النص إلى الحافظة')),
                      );
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.volume_up_outlined, size: 16, color: Colors.white.withOpacity(0.5)),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
