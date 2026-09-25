import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'memory_service.dart';

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

  Future<void> _exportMemory() async {
    try {
      final memoryPath = await MemoryService.getMemoryPath();
      final convPath = await MemoryService.getConversationsPath();
      final memoryFile = File(memoryPath);

      if (!await memoryFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isArabic ? 'لا توجد ذاكرة للتصدير' : 'No memory to export')),
          );
        }
        return;
      }

      final result = await FilePicker.platform.saveFile(
        dialogTitle: _isArabic ? 'احفظ ملف الذاكرة' : 'Save memory file',
        fileName: 'talkgpt_memory_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final content = await memoryFile.readAsString();
        final saveFile = File(result);
        await saveFile.writeAsString(content);

        final convFile = File(convPath);
        if (await convFile.exists()) {
          final convContent = await convFile.readAsString();
          final convSavePath = result.replaceAll('talkgpt_memory_backup.json', 'talkgpt_conversations_backup.json');
          final convSaveFile = File(convSavePath);
          await convSaveFile.writeAsString(convContent);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isArabic ? '✅ تم تصدير الذاكرة والمحادثات' : '✅ Memory and conversations exported'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _importMemory() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: _isArabic ? 'اختر ملف الذاكرة' : 'Select memory file',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final imported = await MemoryService.importMemoryFromFile(result.files.single.path!);
        if (imported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isArabic ? '✅ تم استيراد الذاكرة بنجاح' : '✅ Memory imported successfully'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isArabic ? 'فشل الاستيراد' : 'Import failed')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showMemoryContent() async {
    final memory = await MemoryService.loadMemory();
    final facts = List<dynamic>.from(memory['facts'] ?? []);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isArabic ? 'محتوى الذاكرة' : 'Memory Content',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: facts.isEmpty
              ? Text(
                  _isArabic ? 'الذاكرة فارغة' : 'Memory is empty',
                  style: const TextStyle(color: Colors.white60),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: facts.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF10A37F), fontSize: 18)),
                        Expanded(
                          child: Text(
                            facts[i].toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
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
            _sectionTitle(_isArabic ? 'المظهر' : 'Appearance'),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Color(0xFF10A37F)),
              title: Text(_isArabic ? 'حجم الخط' : 'Font Size', style: const TextStyle(color: Colors.white)),
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
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'اللغة' : 'Language'),
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF10A37F)),
              title: Text(_isArabic ? 'لغة التطبيق' : 'App Language', style: const TextStyle(color: Colors.white)),
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
              title: Text(_isArabic ? 'لغة ردود الذكاء الاصطناعي' : 'AI Response Language', style: const TextStyle(color: Colors.white)),
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
            const Divider(color: Colors.white12),
            _sectionTitle(_isArabic ? 'الذاكرة المؤبدة' : 'Permanent Memory'),
            ListTile(
              leading: const Icon(Icons.visibility, color: Color(0xFF10A37F)),
              title: Text(_isArabic ? 'عرض محتوى الذاكرة' : 'View Memory Content', style: const TextStyle(color: Colors.white)),
              onTap: _showMemoryContent,
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFF10A37F)),
              title: Text(_isArabic ? 'تصدير الذاكرة' : 'Export Memory', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                _isArabic ? 'حفظ نسخة احتياطية في ملفاتي' : 'Save backup to files',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: _exportMemory,
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF10A37F)),
              title: Text(_isArabic ? 'استيراد الذاكرة' : 'Import Memory', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                _isArabic ? 'استعادة من نسخة احتياطية' : 'Restore from backup',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: _importMemory,
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
                    title: Text(_isArabic ? 'تأكيد' : 'Confirm', style: const TextStyle(color: Colors.white)),
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
                        onPressed: () async {
                          await MemoryService.saveConversations([]);
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
                    title: Text(_isArabic ? 'تأكيد' : 'Confirm', style: const TextStyle(color: Colors.white)),
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
                        onPressed: () async {
                          await MemoryService.saveMemory({
                            'facts': <String>[],
                            'userName': '',
                            'preferences': <String>[],
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_isArabic ? 'تم حذف الذاكرة' : 'Memory deleted')),
                            );
                          }
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
              subtitle: Text('v6.0.0', style: TextStyle(color: Colors.white54)),
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
