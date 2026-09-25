import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class MemoryService {
  static const String _memoryFileName = 'talkgpt_memory.json';

  /// حفظ الذاكرة في ملف JSON داخل ذاكرة الهاتف
  static Future<void> saveMemory(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving memory: $e');
    }
  }

  /// قراءة الذاكرة من الملف
  static Future<Map<String, dynamic>?> loadMemory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading memory: $e');
    }
    return null;
  }

  /// حذف الذاكرة
  static Future<void> deleteMemory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting memory: $e');
    }
  }

  /// مسار ملف الذاكرة (للتصدير)
  static Future<String> getMemoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_memoryFileName';
  }
}
