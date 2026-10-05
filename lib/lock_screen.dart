import 'dart:ui';
import 'package:flutter/material.dart';
import 'background_widgets.dart';

class LockScreen extends StatefulWidget {
  final String correctPassword;
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    this.correctPassword = '1234',
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isError = false;
  String _errorMessage = '';

  void _verifyPassword() {
    if (_passwordController.text == widget.correctPassword) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isError = true;
        _errorMessage = 'كلمة المرور غير صحيحة';
      });
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // أيقونة القفل المزخرفة بأسلوب زجاجي
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 48,
                          color: Color(0xFF00D2FF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'مرحباً بك مجدداً',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى إدخال رمز المرور للمتابعة',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // حقل إدخال كلمة المرور الزجاجي
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isError
                                ? Colors.redAccent.withOpacity(0.8)
                                : Colors.white.withOpacity(0.15),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 4,
                          ),
                          decoration: const InputDecoration(
                            hintText: '••••',
                            hintStyle: TextStyle(
                              color: Colors.white30,
                              letterSpacing: 4,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _verifyPassword(),
                          onChanged: (_) {
                            if (_isError) {
                              setState(() => _isError = false);
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  if (_isError) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // زر التأكيد والفتح
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(
                        backgroundBuilder: (context, states, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF00D2FF)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: child,
                          );
                        },
                      ),
                      child: const Text(
                        'فتح التطبيق',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
