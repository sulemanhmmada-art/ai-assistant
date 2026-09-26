import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'memory_service.dart';

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;
  final String password;
  final String selectedModel;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
    required this.password,
    required this.selectedModel,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontSize;
  late String _geminiLanguage;
  late Locale _locale;
  late String _selectedModel;
  String _fontFamily = 'Default';
  String _backgroundType = 'particles';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  final LocalAuthentication _auth = LocalAuthentication();

  bool get _isArabic => _locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _geminiLanguage = widget.geminiLanguage;
    _locale = widget.locale;
    _selectedModel = widget.selectedModel;
    _loadPrefs();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    bool available = false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final biometrics = await _auth.getAvailableBiometrics();
      available = canCheck && isSupported && biometrics.isNotEmpty;
    } catch (_) {}

    final enabled = await MemoryService.isBiometricEnabled();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bg = await MemoryService.getBackgroundType();
    setState(() {
      _fontFamily = prefs.getString('font_family') ?? 'Default';
      _backgroundType = bg;
    });
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  Future<void> _saveGeminiLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_language', lang);
  }

  Future<void> _saveAppLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }

  Future<void> _saveFontFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', family);
    setState(() {
      _fontFamily = family;
    });
  }

  Future<void> _saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', model);
    setState(() {
      _selectedModel = model;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isArabic
              ? 'البصمة غير متاحة على هذا الجهاز'
              : 'Biometric not available'),
        ),
      );
      return;
    }

    if (value) {
      try {
        final didAuth = await _auth.authenticate(
          localizedReason: _isArabic
              ? 'أكد هويتك لتفعيل البصمة'
              : 'Authenticate to enable biometric',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (!didAuth) return;
      } catch (_) {
        return;
      }
    }

    await MemoryService.setBiometricEnabled(value);
    setState(() {
      _biometricEnabled = value;
    });

    if (!value) {
      await MemoryService.deleteStoredPassword();
    } else {
      final stored = await MemoryService.getStoredPassword();
      if (stored == null) {
        await MemoryService.saveStoredPassword(widget.password);
      }
    }
  }

  void _returnResult() {
    Navigator.pop(context, {
      'locale': _locale,
      'fontSize': _fontSize,
      'geminiLanguage': _geminiLanguage,
      'model': _selectedModel,
      'background': _backgroundType,
    });
  }

  Future<void> _deleteAllConversations() async {
    try {
      await MemoryService.saveConversations([], widget.password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic
                ? '✅ تم حذف جميع المحادثات'
                : '✅ All conversations deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteMemory() async {
    try {
      await MemoryService.saveMemory({
        'facts': <String>[],
        'userName': '',
        'preferences': <String>[],
      }, widget.password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic
                ? '✅ تم حذف الذاكرة'
                : '✅ Memory deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isArabic ? 'تغيير كلمة المرور' : 'Change Password',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isArabic ? 'كلمة المرور الحالية' : 'Current password',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isArabic ? 'كلمة المرور الجديدة' : 'New password',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isArabic ? 'تأكيد كلمة المرور' : 'Confirm password',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF764ba2)),
            onPressed: () async {
              if (newController.text.trim().length < 4) return;
              if (newController.text.trim() != confirmController.text.trim()) return;

              final success = await MemoryService.changePassword(
                oldController.text.trim(),
                newController.text.trim(),
              );

              if (mounted) Navigator.pop(context, success);
            },
            child: Text(_isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isArabic ? '✅ تم تغيير كلمة المرور' : '✅ Password changed')),
      );
    } else if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isArabic ? '❌ كلمة المرور القديمة خاطئة' : '❌ Old password is wrong')),
      );
    }
  }

  void _showFontPicker() {
    final fonts = ['Default', 'Cairo', 'Tajawal', 'Almarai', 'Amiri', 'Changa'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
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
            Text(
              _isArabic ? 'اختر الخط' : 'Choose Font',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: fonts.map((font) => _buildFontOption(font)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontOption(String font) {
    final isSelected = _fontFamily == font;

    TextStyle getFontStyle(double size, FontWeight weight) {
      switch (font) {
        case 'Cairo':
          return GoogleFonts.cairo(fontSize: size, fontWeight: weight, color: Colors.white);
        case 'Tajawal':
          return GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: Colors.white);
        case 'Almarai':
          return GoogleFonts.almarai(fontSize: size, fontWeight: weight, color: Colors.white);
        case 'Amiri':
          return GoogleFonts.amiri(fontSize: size, fontWeight: weight, color: Colors.white);
        case 'Changa':
          return GoogleFonts.changa(fontSize: size, fontWeight: weight, color: Colors.white);
        default:
          return TextStyle(fontSize: size, fontWeight: weight, color: Colors.white);
      }
    }

    return ListTile(
      leading: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF764ba2))
          : const Icon(Icons.circle_outlined, color: Colors.white30),
      title: Text(
        font == 'Default' ? (_isArabic ? 'افتراضي' : 'Default') : font,
        style: getFontStyle(18, FontWeight.w600),
      ),
      subtitle: Text(
        font == 'Default'
            ? (_isArabic ? 'خط النظام' : 'System font')
            : (_isArabic ? 'معاينة الخط' : 'Font preview'),
        style: getFontStyle(13, FontWeight.w400).copyWith(color: Colors.white54),
      ),
      onTap: () async {
        await _saveFontFamily(font);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showBackgroundPicker() {
    final backgrounds = [
      {'id': 'particles', 'name_ar': 'جزيئات بلورية', 'name_en': 'Crystal Particles', 'icon': Icons.bubble_chart},
      {'id': 'aurora', 'name_ar': 'شفق قطبي', 'name_en': 'Aurora', 'icon': Icons.gradient},
      {'id': 'wave', 'name_ar': 'موجات سائلة', 'name_en': 'Liquid Wave', 'icon': Icons.waves},
      {'id': 'gradient', 'name_ar': 'تدفق متدرج', 'name_en': 'Gradient Flow', 'icon': Icons.blur_on},
    ];

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
            Text(
              _isArabic ? 'اختر الخلفية' : 'Choose Background',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...backgrounds.map((bg) {
              final isSelected = _backgroundType == bg['id'];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF764ba2), Color(0xFF10A37F)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(bg['icon'] as IconData, color: Colors.white, size: 20),
                ),
                title: Text(
                  _isArabic ? bg['name_ar'] as String : bg['name_en'] as String,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF764ba2) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF764ba2))
                    : null,
                onTap: () async {
                  await MemoryService.setBackgroundType(bg['id'] as String);
                  setState(() {
                    _backgroundType = bg['id'] as String;
                  });
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showModelPicker() {
    final models = [
      {'id': 'auto', 'name_ar': 'تلقائي (3.6 → 2.5 → Pollinations)', 'name_en': 'Auto (3.6 → 2.5 → Pollinations)', 'icon': Icons.auto_awesome},
      {'id': 'gemini-3.6', 'name_ar': 'Gemini 3.6 Flash', 'name_en': 'Gemini 3.6 Flash', 'icon': Icons.star},
      {'id': 'gemini-2.5', 'name_ar': 'Gemini 2.5 Flash', 'name_en': 'Gemini 2.5 Flash', 'icon': Icons.flash_on},
      {'id': 'pollinations', 'name_ar': 'Pollinations (مجاني)', 'name_en': 'Pollinations (Free)', 'icon': Icons.cloud},
    ];

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
            Text(
              _isArabic ? 'اختر النموذج' : 'Choose Model',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...models.map((m) {
              final isSelected = _selectedModel == m['id'];
              return ListTile(
                leading: Icon(
                  m['icon'] as IconData,
                  color: isSelected ? const Color(0xFF764ba2) : Colors.white54,
                ),
                title: Text(
                  _isArabic ? m['name_ar'] as String : m['name_en'] as String,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF764ba2) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF764ba2))
                    : null,
                onTap: () async {
                  await _saveModel(m['id'] as String);
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1116),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0E1116),
          elevation: 0,
          title: Text(
            _isArabic ? 'الإعدادات' : 'Settings',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _returnResult,
          ),
        ),
        body: ListView(
          children: [
            _sectionTitle(_isArabic ? 'النموذج' : 'Model'),
            ListTile(
              leading: const Icon(Icons.smart_toy, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'نموذج الذكاء الاصطناعي' : 'AI Model',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _modelName(),
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
              onTap: _showModelPicker,
            ),
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'المظهر' : 'Appearance'),
            ListTile(
              leading: const Icon(Icons.wallpaper, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'الخلفية' : 'Background',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _backgroundName(),
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
              onTap: _showBackgroundPicker,
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'حجم الخط' : 'Font Size',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${_fontSize.toInt()} ${_isArabic ? "نقطة" : "pt"}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('A', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 10,
                      max: 24,
                      divisions: 14,
                      activeColor: const Color(0xFF764ba2),
                      label: '${_fontSize.toInt()}',
                      onChanged: (value) {
                        setState(() => _fontSize = value);
                        _saveFontSize(value);
                      },
                    ),
                  ),
                  const Text('A', style: TextStyle(color: Colors.white, fontSize: 22)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.font_download, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'نوع الخط' : 'Font Family',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _fontFamily == 'Default'
                    ? (_isArabic ? 'افتراضي' : 'Default')
                    : _fontFamily,
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
              onTap: _showFontPicker,
            ),
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'اللغة' : 'Language'),
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'لغة التطبيق' : 'App Language',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _locale.languageCode == 'ar' ? 'العربية' : 'English',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _langButton(
                      label: 'العربية',
                      selected: _locale.languageCode == 'ar',
                      onTap: () {
                        setState(() => _locale = const Locale('ar'));
                        _saveAppLanguage('ar');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _langButton(
                      label: 'English',
                      selected: _locale.languageCode == 'en',
                      onTap: () {
                        setState(() => _locale = const Locale('en'));
                        _saveAppLanguage('en');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'لغة ردود الذكاء الاصطناعي' : 'AI Response Language',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _geminiLanguageName(),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _langChip('ar', 'العربية'),
                  _langChip('en', 'English'),
                  _langChip('fr', 'Français'),
                  _langChip('es', 'Español'),
                  _langChip('tr', 'Türkçe'),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'الأمان' : 'Security'),
            if (_biometricAvailable)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint, color: Color(0xFF764ba2)),
                title: Text(
                  _isArabic ? 'الدخول بالبصمة' : 'Biometric Login',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _isArabic
                      ? 'استخدم بصمة الأصابع للدخول'
                      : 'Use fingerprint to log in',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: _biometricEnabled,
                activeColor: const Color(0xFF764ba2),
                onChanged: _toggleBiometric,
              ),
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFF764ba2)),
              title: Text(
                _isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _isArabic ? 'يتطلب كلمة المرور الحالية' : 'Requires current password',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: _changePassword,
            ),
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'البيانات' : 'Data'),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                _isArabic ? 'حذف جميع المحادثات' : 'Delete All Conversations',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF16213E),
                    title: Text(
                      _isArabic ? 'تأكيد' : 'Confirm',
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      _isArabic
                          ? 'سيتم حذف جميع المحادثات، لكن الذاكرة ستبقى.'
                          : 'All conversations will be deleted, but memory will remain.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteAllConversations();
                        },
                        child: Text(_isArabic ? 'حذف الكل' : 'Delete All'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.red),
              title: Text(
                _isArabic ? 'حذف الذاكرة المؤبدة' : 'Delete Permanent Memory',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF16213E),
                    title: Text(
                      _isArabic ? 'تأكيد' : 'Confirm',
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      _isArabic
                          ? 'سيتم حذف كل المعلومات الشخصية المحفوظة. لا يمكن التراجع.'
                          : 'All stored personal information will be deleted. Cannot be undone.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteMemory();
                        },
                        child: Text(_isArabic ? 'حذف' : 'Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'حول' : 'About'),
            const ListTile(
              leading: Icon(Icons.info_outline, color: Color(0xFF764ba2)),
              title: Text('TalkGPT', style: TextStyle(color: Colors.white)),
              subtitle: Text('v14.0.0', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _modelName() {
    switch (_selectedModel) {
      case 'gemini-3.6':
        return 'Gemini 3.6 Flash';
      case 'gemini-2.5':
        return 'Gemini 2.5 Flash';
      case 'pollinations':
        return 'Pollinations';
      default:
        return _isArabic ? 'تلقائي' : 'Auto';
    }
  }

  String _backgroundName() {
    switch (_backgroundType) {
      case 'aurora':
        return _isArabic ? 'شفق قطبي' : 'Aurora';
      case 'wave':
        return _isArabic ? 'موجات سائلة' : 'Liquid Wave';
      case 'gradient':
        return _isArabic ? 'تدفق متدرج' : 'Gradient Flow';
      default:
        return _isArabic ? 'جزيئات بلورية' : 'Crystal Particles';
    }
  }

  String _geminiLanguageName() {
    switch (_geminiLanguage) {
      case 'ar': return 'العربية';
      case 'en': return 'English';
      case 'fr': return 'Français';
      case 'es': return 'Español';
      case 'tr': return 'Türkçe';
      default: return 'العربية';
    }
  }

  Widget _langButton({required String label, required bool selected, required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF764ba2) : const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }

  Widget _langChip(String code, String label) {
    final selected = _geminiLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() => _geminiLanguage = code);
        _saveGeminiLanguage(code);
      },
      selectedColor: const Color(0xFF764ba2),
      backgroundColor: const Color(0xFF1E1E1E),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF764ba2),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
