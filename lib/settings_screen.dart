import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'memory_service.dart';

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;
  final String password;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
    required this.password,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontSize;
  late String _geminiLanguage;
  late Locale _locale;
  String _fontFamily = 'Default';

  bool get _isArabic => _locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _geminiLanguage = widget.geminiLanguage;
    _locale = widget.locale;
    _loadFontFamily();
  }

  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontFamily = prefs.getString('font_family') ?? 'Default';
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

  void _returnResult() {
    Navigator.pop(context, {
      'locale': _locale,
      'fontSize': _fontSize,
      'geminiLanguage': _geminiLanguage,
    });
  }

  Future<void> _deleteAllConversations() async {
    try {
      await MemoryService.saveConversations([], widget.password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isArabic ? '✅ تم حذف جميع المحادثات' : '✅ All conversations deleted'),
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
            content: Text(_isArabic ? '✅ تم حذف الذاكرة' : '✅ Memory deleted'),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F)),
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
              _isArabic ? 'اختر الخط' : 'Choose Font',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...fonts.map((font) => _buildFontOption(font)),
            const SizedBox(height: 12),
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
          ? const Icon(Icons.check_circle, color: Color(0xFF10A37F))
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
      onTap: () {
        _saveFontFamily(font);
        Navigator.pop(context);
      },
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
            _sectionTitle(_isArabic ? 'المظهر' : 'Appearance'),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Color(0xFF10A37F)),
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
                      activeColor: const Color(0xFF10A37F),
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
              leading: const Icon(Icons.font_download, color: Color(0xFF10A37F)),
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
              leading: const Icon(Icons.language, color: Color(0xFF10A37F)),
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
              leading: const Icon(Icons.record_voice_over, color: Color(0xFF10A37F)),
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
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFF10A37F)),
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
              leading: Icon(Icons.info_outline, color: Color(0xFF10A37F)),
              title: Text('TalkGPT', style: TextStyle(color: Colors.white)),
              subtitle: Text('v10.0.0', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
        backgroundColor: selected ? const Color(0xFF10A37F) : const Color(0xFF1E1E1E),
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
      selectedColor: const Color(0xFF10A37F),
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
          color: Color(0xFF10A37F),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
