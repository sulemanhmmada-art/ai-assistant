import 'dart:ui';
import 'package:flutter/material.dart';
import 'background_widgets.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String correctPassword;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    required this.correctPassword,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;

  void _verifyPassword() {
    if (_controller.text == widget.correctPassword) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'كلمة المرور غير صحيحة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. الهالة السائلة المضيئة كشعار احترافي
                const AiOrbWidget(size: 150),
                const SizedBox(height: 28),

                const Text(
                  'TalkGPT',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل كلمة المرور للمتابعة',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 36),

                // 2. كارت زجاجي شفاف (Glassmorphic Container)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            obscureText: _obscureText,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'كلمة المرور',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00D2FF)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.25),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _verifyPassword(),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // 3. زر الدخول بتدرج نيون انسيابي
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _verifyPassword,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF00D2FF)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'دخول',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
