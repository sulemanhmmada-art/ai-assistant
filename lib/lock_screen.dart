import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:local_auth/local_auth.dart';
import 'memory_service.dart';

class LockScreen extends StatefulWidget {
  final Function(String) onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _rippleController;

  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rippleAnimation;

  bool _isFirstTime = true;
  bool _showError = false;
  bool _isLoading = true;
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _rippleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });

    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final hasPass = await MemoryService.hasPassword();
    final bioEnabled = await MemoryService.isBiometricEnabled();

    bool bioAvailable = false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final availableBiometrics = await _auth.getAvailableBiometrics();
      bioAvailable = canCheck && isSupported && availableBiometrics.isNotEmpty;
    } catch (_) {}

    setState(() {
      _isFirstTime = !hasPass;
      _biometricEnabled = bioEnabled;
      _biometricAvailable = bioAvailable;
      _isLoading = false;
    });

    if (!_isFirstTime && _biometricEnabled && _biometricAvailable) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _authenticateBiometric();
      });
    }
  }

  Future<void> _authenticateBiometric() async {
    if (!_biometricAvailable || !_biometricEnabled) return;

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'أدخل بصمتك للدخول إلى TalkGPT',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final password = await MemoryService.getStoredPassword();
        if (password != null) {
          widget.onUnlocked(password);
        } else {
          setState(() {
            _showError = true;
          });
        }
      }
    } catch (e) {
      print('Biometric error: $e');
    }
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _rippleController.dispose();
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _setupPassword() async {
    final pass = _controller.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 4 || pass != confirm) {
      setState(() => _showError = true);
      return;
    }

    setState(() {
      _showError = false;
      _isSubmitting = true;
    });
    _rippleController.forward();

    final success = await MemoryService.setPassword(pass);

    if (success) {
      await MemoryService.saveStoredPassword(pass);
      widget.onUnlocked(pass);
    } else {
      setState(() {
        _showError = true;
        _isSubmitting = false;
      });
      _rippleController.reset();
    }
  }

  Future<void> _verifyPassword() async {
    final pass = _controller.text.trim();

    setState(() {
      _showError = false;
      _isSubmitting = true;
    });
    _rippleController.forward();

    final valid = await MemoryService.verifyPassword(pass);

    if (valid) {
      await MemoryService.saveStoredPassword(pass);
      widget.onUnlocked(pass);
    } else {
      setState(() {
        _showError = true;
        _isSubmitting = false;
      });
      _rippleController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1116),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10A37F)),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E1116),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              ...List.generate(6, (index) => _buildFloatingElement(index)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogoSection(),
                          const SizedBox(height: 40),
                          _buildGlassCard(),
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

  Widget _buildFloatingElement(int index) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Positioned(
          left: (index * 60.0) + _floatingAnimation.value,
          top: (index * 80.0) + (_floatingAnimation.value * 0.5),
          child: Transform.rotate(
            angle: _floatingController.value * 2 * math.pi + (index * 0.5),
            child: Container(
              width: 40 + (index * 10),
              height: 40 + (index * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10A37F).withValues(alpha: 0.15),
                    const Color(0xFF10A37F).withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10A37F).withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10A37F).withValues(alpha: 0.4),
                      const Color(0xFF10A37F).withValues(alpha: 0.15),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10A37F).withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 45,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TalkGPT',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isFirstTime
                    ? 'أنشئ كلمة مرور لحماية بياناتك'
                    : 'أدخل كلمة المرور للدخول',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!_isFirstTime && _biometricEnabled && _biometricAvailable) ...[
                GestureDetector(
                  onTap: _authenticateBiometric,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10A37F), Color(0xFF764ba2)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10A37F).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'اضغط للدخول بالبصمة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'أو',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              _buildGlassTextField(
                controller: _controller,
                hint: 'كلمة المرور',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              if (_isFirstTime) ...[
                const SizedBox(height: 16),
                _buildGlassTextField(
                  controller: _confirmController,
                  hint: 'تأكيد كلمة المرور',
                  icon: Icons.lock,
                  isPassword: true,
                ),
              ],
              if (_showError) ...[
                const SizedBox(height: 12),
                Text(
                  _isFirstTime
                      ? 'كلمة المرور قصيرة أو غير متطابقة'
                      : 'كلمة المرور خاطئة',
                  style: const TextStyle(
                    color: Color(0xFFF5576C),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildGlassButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF10A37F),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton() {
    return AnimatedBuilder(
      animation: _rippleAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          child: Stack(
            children: [
              if (_isSubmitting)
                Positioned.fill(
                  child: CustomPaint(
                    painter: RipplePainter(_rippleAnimation.value),
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10A37F).withValues(alpha: 0.7),
                          const Color(0xFF10A37F).withValues(alpha: 0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10A37F).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSubmitting
                            ? null
                            : (_isFirstTime ? _setupPassword : _verifyPassword),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isFirstTime ? 'إنشاء وحفظ' : 'دخول',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final double animationValue;

  RipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.7;
    final radius = maxRadius * animationValue;

    final paint = Paint()
      ..color = const Color(0xFF10A37F).withValues(alpha: 0.3 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
