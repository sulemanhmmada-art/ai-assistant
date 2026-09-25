import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  /// توليد Salt عشوائي (16 بايت)
  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// اشتقاق مفتاح AES-256 من كلمة المرور + Salt باستخدام PBKDF2
  static enc.Key _deriveKey(String password, String saltBase64) {
    final salt = base64Decode(saltBase64);
    final passwordBytes = utf8.encode(password);

    // PBKDF2 مع 100,000 دورة (معيار عسكري)
    final derivator = _PBKDF2KeyDerivator();
    final keyBytes = derivator.deriveKey(
      passwordBytes,
      salt,
      100000,
      32, // 256-bit key
    );

    return enc.Key(Uint8List.fromList(keyBytes));
  }

  /// تشفير نص باستخدام AES-256-GCM
  static Map<String, String> encryptText(String plainText, String password, String saltBase64) {
    final key = _deriveKey(password, saltBase64);
    final iv = enc.IV.fromSecureRandom(12); // 96-bit IV for GCM

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return {
      'ciphertext': encrypted.base64,
      'iv': iv.base64,
    };
  }

  /// فك تشفير نص باستخدام AES-256-GCM
  static String? decryptText(String cipherText, String ivBase64, String password, String saltBase64) {
    try {
      final key = _deriveKey(password, saltBase64);
      final iv = enc.IV.fromBase64(ivBase64);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final decrypted = encrypter.decrypt64(cipherText, iv: iv);
      return decrypted;
    } catch (e) {
      return null;
    }
  }

  /// تشفير Map كاملة
  static String encryptJson(Map<String, dynamic> data, String password, String saltBase64) {
    final plainText = jsonEncode(data);
    final encrypted = encryptText(plainText, password, saltBase64);

    final result = {
      'salt': saltBase64,
      'iv': encrypted['iv'],
      'ciphertext': encrypted['ciphertext'],
      'version': 1,
    };

    return jsonEncode(result);
  }

  /// فك تشفير Map كاملة
  static Map<String, dynamic>? decryptJson(String encryptedJson, String password) {
    try {
      final outer = jsonDecode(encryptedJson) as Map<String, dynamic>;
      final salt = outer['salt'] as String;
      final iv = outer['iv'] as String;
      final ciphertext = outer['ciphertext'] as String;

      final decrypted = decryptText(ciphertext, iv, password, salt);
      if (decrypted == null) return null;

      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Hash كلمة المرور للتحقق
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }

  /// توليد salt ثابت لكلمة المرور
  static String generatePasswordSalt() {
    return generateSalt();
  }
}

/// PBKDF2 Implementation
class _PBKDF2KeyDerivator {
  List<int> deriveKey(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength / 32).ceil();
    final derivedKey = <int>[];

    for (int block = 1; block <= blockCount; block++) {
      // U1 = HMAC(password, salt || INT(block))
      final blockBytes = <int>[];
      blockBytes.addAll(salt);
      blockBytes.addAll(_intToBytes(block));

      var u = hmac.convert(blockBytes).bytes;
      final result = List<int>.from(u);

      // U2..Uc = HMAC(password, U_{i-1})
      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < result.length; j++) {
          result[j] ^= u[j];
        }
      }

      derivedKey.addAll(result);
    }

    return derivedKey.sublist(0, keyLength);
  }

  List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
