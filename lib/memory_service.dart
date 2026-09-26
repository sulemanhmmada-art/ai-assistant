import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'crypto_service.dart';

class MemoryService {
  static const String _memoryFileName = 'talkgpt_memory.json';
  static const String _conversationsFileName = 'talkgpt_conversations.json';
  static const String _authFileName = '.talkgpt_auth';
  static const String _prefsFileName = '.talkgpt_prefs';
  static const String _storedPassFileName = '.talkgpt_stored_pass';

  // ========== تفضيلات ==========

  static Future<Map<String, dynamic>> loadPrefs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'biometric_enabled': false,
      'background_type': 'particles',
    };
  }

  static Future<void> savePrefs(Map<String, dynamic> prefs) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');
      await file.writeAsString(jsonEncode(prefs));
    } catch (_) {}
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await loadPrefs();
    return prefs['biometric_enabled'] == true;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await loadPrefs();
    prefs['biometric_enabled'] = enabled;
    await savePrefs(prefs);
  }

  static Future<String> getBackgroundType() async {
    final prefs = await loadPrefs();
    return prefs['background_type'] ?? 'particles';
  }

  static Future<void> setBackgroundType(String type) async {
    final prefs = await loadPrefs();
    prefs['background_type'] = type;
    await savePrefs(prefs);
  }

  // ========== تخزين كلمة المرور للبصمة ==========

  static Future<void> saveStoredPassword(String password) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_storedPassFileName');
      final encoded = base64Encode(utf8.encode(password));
      await file.writeAsString(encoded);
    } catch (_) {}
  }

  static Future<String?> getStoredPassword() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_storedPassFileName');
      if (await file.exists()) {
        final encoded = await file.readAsString();
        return utf8.decode(base64Decode(encoded));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteStoredPassword() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_storedPassFileName');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ========== كلمة المرور ==========

  static Future<Map<String, String>?> getAuthData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_authFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        return Map<String, String>.from(jsonDecode(content));
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> setPassword(String password) async {
    try {
      final salt = CryptoService.generatePasswordSalt();
      final hash = CryptoService.hashPassword(password, salt);
      final data = {'salt': salt, 'hash': hash};

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_authFileName');
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> verifyPassword(String password) async {
    final authData = await getAuthData();
    if (authData == null) return false;
    final hash = CryptoService.hashPassword(password, authData['salt']!);
    return hash == authData['hash'];
  }

  static Future<bool> hasPassword() async {
    return (await getAuthData()) != null;
  }

  static Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!await verifyPassword(oldPassword)) return false;

    final memory = await loadMemory(oldPassword);
    final conversations = await loadConversations(oldPassword);

    await setPassword(newPassword);
    await saveStoredPassword(newPassword);

    await saveMemory(memory, newPassword);
    await saveConversations(conversations, newPassword);

    return true;
  }

  // ========== الذاكرة الشخصية ==========

  static Future<Map<String, dynamic>> loadMemory(String password) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      if (await file.exists()) {
        final encrypted = await file.readAsString();
        final decrypted = CryptoService.decryptJson(encrypted, password);
        if (decrypted != null) return decrypted;
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

  static Future<void> saveMemory(Map<String, dynamic> data, String password) async {
    try {
      data['lastUpdated'] = DateTime.now().toIso8601String();
      final authData = await getAuthData();
      if (authData == null) return;

      final encrypted = CryptoService.encryptJson(data, password, authData['salt']!);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_memoryFileName');
      await file.writeAsString(encrypted);
    } catch (e) {
      print('Error saving memory: $e');
    }
  }

  static Future<void> addFact(String fact, String password) async {
    final memory = await loadMemory(password);
    final List<dynamic> facts = List<dynamic>.from(memory['facts'] ?? []);
    if (!facts.contains(fact)) {
      facts.add(fact);
      memory['facts'] = facts;
      await saveMemory(memory, password);
    }
  }

  static Future<void> extractFacts(String text, String password) async {
    final patterns = [
      RegExp(r'اسمي\s+([^\n\.،,]+)'),
      RegExp(r'أنا\s+([^\n\.،,]+)'),
      RegExp(r'أدرس\s+([^\n\.،,]+)'),
      RegExp(r'أعمل\s+([^\n\.،,]+)'),
      RegExp(r'عمري\s+([^\n\.،,]+)'),
      RegExp(r'أحب\s+([^\n\.،,]+)'),
      RegExp(r'أسكن\s+في\s+([^\n\.،,]+)'),
      RegExp(r'My name is\s+([^\n\.،,]+)'),
      RegExp(r'I am\s+([^\n\.،,]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final fact = match.group(0)?.trim() ?? '';
        if (fact.isNotEmpty && fact.length < 200) {
          await addFact(fact, password);
        }
      }
    }
  }

  static Future<String> getMemoryAsText(String password) async {
    final memory = await loadMemory(password);
    final facts = List<dynamic>.from(memory['facts'] ?? []);
    if (facts.isEmpty) return '';
    return 'معلومات عني: ${facts.join(' | ')}';
  }

  // ========== المحادثات ==========

  static Future<List<Map<String, dynamic>>> loadConversations(String password) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_conversationsFileName');
      if (await file.exists()) {
        final encrypted = await file.readAsString();
        final outer = jsonDecode(encrypted) as Map<String, dynamic>;
        final decrypted = CryptoService.decryptText(
          outer['ciphertext'] as String,
          outer['iv'] as String,
          password,
          outer['salt'] as String,
        );
        if (decrypted != null) {
          final list = jsonDecode(decrypted) as List<dynamic>;
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      print('Error loading conversations: $e');
    }
    return [];
  }

  static Future<void> saveConversations(List<Map<String, dynamic>> conversations, String password) async {
    try {
      final authData = await getAuthData();
      if (authData == null) return;

      final jsonStr = jsonEncode(conversations);
      final encrypted = CryptoService.encryptText(jsonStr, password, authData['salt']!);

      final result = {
        'salt': authData['salt']!,
        'iv': encrypted['iv']!,
        'ciphertext': encrypted['ciphertext']!,
        'version': 1,
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_conversationsFileName');
      await file.writeAsString(jsonEncode(result));
    } catch (e) {
      print('Error saving conversations: $e');
    }
  }
}
