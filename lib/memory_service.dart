import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class MemoryService {
  static const String _memoryFileName = 'talkgpt_memory.json';
  static const String _conversationsFileName = 'talkgpt_conversations.json';

  // ========== كلمة المرور ==========

  static Future<String?> getPasswordHash() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/.talkgpt_auth');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  static Future<bool> setPassword(String password) async {
    try {
      final hash = _hashPassword(password);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/.talkgpt_auth');
      await file.writeAsString(hash);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> verifyPassword(String password) async {
    final storedHash = await getPasswordHash();
    if (storedHash == null) return false;
    return storedHash == _hashPassword(password);
  }

  static Future<bool> hasPassword() async {
    return (await getPasswordHash()) != null;
  }

  static Future<void> removePassword() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/.talkgpt_auth');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static String _hashPassword(String password) {
    final salt = 'talkgpt_salt_2024';
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }

  // ========== الذاكرة الشخصية ==========

  static Future<Map<String, dynamic>> loadMemory() async {
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
    return {
      'facts': <String>[],
      'userName': '',
      'preferences': <String>[],
      'lastUpdated': '',
    };
  }

  static Future<void> saveMemory(Map<String, dynamic> data) async {
    try {
      data['lastUpdated'] = DateTime.now().toIso8601String();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving memory: $e');
    }
  }

  static Future<void> addFact(String fact) async {
    final memory = await loadMemory();
    final List<dynamic> facts = List<dynamic>.from(memory['facts'] ?? []);
    if (!facts.contains(fact)) {
      facts.add(fact);
      memory['facts'] = facts;
      await saveMemory(memory);
    }
  }

  static Future<void> extractFacts(String text) async {
    final patterns = [
      RegExp(r'اسمي\s+([^\n\.،,]+)'),
      RegExp(r'أنا\s+([^\n\.،,]+)'),
      RegExp(r'أدرس\s+([^\n\.،,]+)'),
      RegExp(r'أعمل\s+([^\n\.،,]+)'),
      RegExp(r'عمري\s+([^\n\.،,]+)'),
      RegExp(r'أحب\s+([^\n\.،,]+)'),
      RegExp(r'أكره\s+([^\n\.،,]+)'),
      RegExp(r'أسكن\s+في\s+([^\n\.،,]+)'),
      RegExp(r'My name is\s+([^\n\.،,]+)'),
      RegExp(r'I am\s+([^\n\.،,]+)'),
      RegExp(r'I study\s+([^\n\.،,]+)'),
      RegExp(r'I work\s+([^\n\.،,]+)'),
      RegExp(r'I love\s+([^\n\.،,]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final fact = match.group(0)?.trim() ?? '';
        if (fact.isNotEmpty && fact.length < 200) {
          await addFact(fact);
        }
      }
    }
  }

  static Future<String> getMemoryAsText() async {
    final memory = await loadMemory();
    final facts = List<dynamic>.from(memory['facts'] ?? []);
    if (facts.isEmpty) return '';
    return 'معلومات عني: ${facts.join(' | ')}';
  }

  // ========== المحادثات ==========

  static Future<List<Map<String, dynamic>>> loadConversations() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_conversationsFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      print('Error loading conversations: $e');
    }
    return [];
  }

  static Future<void> saveConversations(List<Map<String, dynamic>> conversations) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_conversationsFileName');
      await file.writeAsString(jsonEncode(conversations));
    } catch (e) {
      print('Error saving conversations: $e');
    }
  }
}
