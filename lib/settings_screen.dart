import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final String geminiLanguage;
  final Locale locale;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.geminiLanguage,
    required this.locale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontSize;
  late String _geminiLanguage;
  late Locale _locale;

  bool get _isArabic => _locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _geminiLanguage = widget.geminiLanguage;
    _locale = widget.locale;
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

  void _returnResult() {
    Navigator.pop(context, {
      'locale': _locale,
      'fontSize': _fontSize,
      'geminiLanguage': _geminiLanguage,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isArabic ? 'الإعدادات' : 'Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _returnResult,
          ),
        ),
        body: ListView(
          children: [
            _sectionTitle(_isArabic ? 'المظهر' : 'Appearance'),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.blue),
              title: Text(_isArabic ? 'حجم الخط' : 'Font Size'),
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
            const Divider(color: Colors.white24),
            _sectionTitle(_isArabic ? 'اللغة' : 'Language'),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.green),
              title: Text(_isArabic ? 'لغة التطبيق' : 'App Language'),
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
              leading: const Icon(Icons.record_voice_over, color: Colors.purple),
              title: Text(_isArabic ? 'لغة ردود الذكاء الاصطناعي' : 'AI Response Language'),
              subtitle: Text(_geminiLanguageName(), style: const TextStyle(color: Colors.white54)),
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
            const Divider(color: Colors.white24),
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
                    title: Text(_isArabic ? 'تأكيد' : 'Confirm'),
                    content: Text(
                      _isArabic ? 'سيتم حذف جميع المحادثات نهائياً.' : 'All conversations will be deleted.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('conversations');
                          if (mounted) {
                            Navigator.pop(context);
                            _returnResult();
                          }
                        },
                        child: Text(_isArabic ? 'حذف الكل' : 'Delete All'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24),
            _sectionTitle(_isArabic ? 'حول' : 'About'),
            const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.blue),
              title: Text('TalkGPT', style: TextStyle(color: Colors.white)),
              subtitle: Text('v3.0.0', style: TextStyle(color: Colors.white54)),
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
        backgroundColor: selected ? Colors.blue : const Color(0xFF16213E),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      selectedColor: Colors.purple,
      backgroundColor: const Color(0xFF16213E),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
