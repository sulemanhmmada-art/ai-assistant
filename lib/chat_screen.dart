Future<void> _pickAndAnalyzeImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
  if (picked == null) return;

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
          hintText: _isArabic
              ? 'اكتب سؤالك عن الصورة (اختياري)...'
              : 'Ask about the image (optional)...',
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
  if (_currentConversationId == null) return;

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
        'mode': 'analyze',
        'prompt': prompt,
        'image': base64Image,
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
