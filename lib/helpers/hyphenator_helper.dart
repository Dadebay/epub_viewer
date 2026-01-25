import 'package:hyphenatorx/hyphenatorx.dart';
import 'package:hyphenatorx/languages/language_en_us.dart';
import 'package:hyphenatorx/languages/language_ru.dart';
import 'package:hyphenatorx/languages/language_tr.dart';
import 'package:hyphenatorx/languages/language_tk.dart';

/// Helper class for hyphenating text in multiple languages
/// Supports: Russian (ru), English (en_us), Turkish (tr), Turkmen (tk)
class HyphenatorHelper {
  static HyphenatorHelper? _instance;

  Hyphenator? _russianHyphenator;
  Hyphenator? _englishHyphenator;
  Hyphenator? _turkishHyphenator;
  Hyphenator? _turkmenHyphenator;

  bool _isInitialized = false;

  // Zero-width space - satır bölünmesine izin verir ama görünmez
  static const String _zwsp = '\u200B';

  // Soft hyphen - satır sonunda bölünme olursa tire gösterir, yoksa görünmez
  static const String _softHyphen = '\u00AD';

  HyphenatorHelper._();

  static HyphenatorHelper get instance {
    _instance ??= HyphenatorHelper._();
    return _instance!;
  }

  /// Initialize all hyphenators synchronously
  void initialize() {
    if (_isInitialized) return;

    try {
      // Soft hyphen kullan - satır sonunda tire olarak görünür, aksi halde görünmez

      // Russian hyphenator
      _russianHyphenator = Hyphenator(
        Language_ru(),
        symbol: _softHyphen,
      );

      // English hyphenator
      _englishHyphenator = Hyphenator(
        Language_en_us(),
        symbol: _softHyphen,
      );

      // Turkish hyphenator
      _turkishHyphenator = Hyphenator(
        Language_tr(),
        symbol: _softHyphen,
      );

      // Turkmen hyphenator
      _turkmenHyphenator = Hyphenator(
        Language_tk(),
        symbol: _softHyphen,
      );

      _isInitialized = true;
      print('📝 HyphenatorHelper initialized for RU, EN, TR, TK languages (soft hyphen mode)');
    } catch (e) {
      print('⚠️ HyphenatorHelper initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// Detect language from text content
  Language detectLanguage(String text) {
    if (text.isEmpty) return Language.english;

    // Count character types
    int cyrillicCount = 0;
    int latinCount = 0;
    int turkmenSpecificCount = 0;

    for (int i = 0; i < text.length && i < 500; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // Cyrillic range: 0x0400-0x04FF
      if (code >= 0x0400 && code <= 0x04FF) {
        cyrillicCount++;
      }
      // Basic Latin range: 0x0041-0x007A
      else if ((code >= 0x0041 && code <= 0x005A) || (code >= 0x0061 && code <= 0x007A)) {
        latinCount++;
      }

      // Turkmen specific characters: ä, ň, ö, ü, ý, ž, ş
      if ('äňöüýžşÄŇÖÜÝŽŞ'.contains(char)) {
        turkmenSpecificCount++;
      }
    }

    // Determine language
    if (cyrillicCount > latinCount) {
      return Language.russian;
    } else if (turkmenSpecificCount > 3) {
      return Language.turkmen;
    } else {
      return Language.english;
    }
  }

  /// Hyphenate text based on detected or specified language
  /// Soft hyphen kullanır - satır sonunda tire olarak görünür, aksi halde görünmez
  String hyphenate(String text, {Language? language}) {
    if (!_isInitialized || text.isEmpty) return text;

    // Don't hyphenate very short text
    if (text.length < 8) return text;

    final lang = language ?? detectLanguage(text);

    try {
      String result;
      switch (lang) {
        case Language.russian:
          result = _russianHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.english:
          result = _englishHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.turkmen:
          result = _turkmenHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.turkish:
          result = _turkishHyphenator?.hyphenateText(text) ?? text;
          break;
      }

      // Soft hyphen zaten eklendi, ek işlem gerekmez
      return result;
    } catch (e) {
      // If hyphenation fails, return original text
      return text;
    }
  }

  /// Hyphenate a single word
  String hyphenateWord(String word, {Language? language}) {
    if (!_isInitialized || word.isEmpty || word.length < 4) return word;

    final lang = language ?? detectLanguage(word);

    try {
      String result;
      switch (lang) {
        case Language.russian:
          result = _russianHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.english:
          result = _englishHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.turkmen:
          result = _turkmenHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.turkish:
          result = _turkishHyphenator?.hyphenateWord(word) ?? word;
          break;
      }

      // Soft hyphen zaten eklendi
      return result;
    } catch (e) {
      return word;
    }
  }

  /// Check if helper is initialized
  bool get isInitialized => _isInitialized;
}

enum Language {
  russian,
  english,
  turkish,
  turkmen,
}
