import 'package:flutter/material.dart';
import 'memory_service.dart';

class LockScreen extends StatefulWidget {
  final Function(String) onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isFirstTime = true;
  bool _showError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  Future<void> _checkPasswordStatus() async {
    final hasPass = await MemoryService.hasPassword();
    setState(() {
      _isFirstTime = !hasPass;
      _isLoading = false;
    });
  }

  Future<void> _setupPassword() async {
    final pass = _controller.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 4) {
      setState(() => _showError = true);
      return;
    }

    if (pass != confirm) {
      setState(() => _showError = true);
      return;
    }

    final success = await MemoryService.setPassword(pass);
    if (success) {
      widget.onUnlocked(pass);
    }
  }

  Future<void> _verifyPassword() async {
    final pass = _controller.text.trim();
    final valid = await MemoryService.verifyPassword(pass);
    if (valid) {
      widget.onUnlocked(pass);
    } else {
      setState(() => _showError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1116),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1116),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10A37F).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 60,
                    color: Color(0xFF10A37F),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isFirstTime ? 'إنشاء كلمة مرور' : 'أدخل كلمة المرور',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isFirstTime
                      ? 'كلمة المرور تحمي ذاكرتك المؤبدة بتشفير AES-256'
                      : 'بياناتك مشفّرة، أدخل كلمة المرور للوصول',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF10A37F)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_isFirstTime) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'تأكيد كلمة المرور',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF10A37F)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                if (_showError) ...[
                  const SizedBox(height: 12),
                  Text(
                    _isFirstTime
                        ? 'كلمة المرور قصيرة أو غير متطابقة'
                        : 'كلمة المرور خاطئة',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isFirstTime ? _setupPassword : _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10A37F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isFirstTime ? 'إنشاء وحفظ' : 'دخول',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🔒 كلمة المرور تُخزَّن كـ Hash فقط، لا يمكن استرجاعها',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
