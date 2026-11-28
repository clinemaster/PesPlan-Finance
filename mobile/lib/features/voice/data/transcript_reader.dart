import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/domain/transaction_draft.dart';
import '../domain/voice_extraction.dart';

/// Reads a spoken sentence and says what it seems to describe.
///
/// ## A keyword reader, not a model
///
/// This is the stand-in for the extraction service Phase 17 brings. It
/// knows a few hundred Kiswahili and English words — the verbs that say
/// which way money went, the number words up to a million, the things
/// people in the launch market actually spend on — and it marks anything
/// it cannot place rather than guessing. No model, no network, no
/// learning.
///
/// It is deliberately a real reader rather than a lookup of canned
/// sentences: the user can correct the transcript before anything is
/// extracted, and a canned table would ignore the correction, which is
/// the one thing that step exists for.
///
/// ## This file is allowed to add up money
///
/// Turning "elfu arobaini na tano" into 45,000 is arithmetic on an
/// amount, which Architecture Rule 1 keeps out of the app. It is here
/// because this class plays the server; `test/transactions/
/// architecture_test.dart` fails the build if it leaks upward.
abstract final class TranscriptReader {
  /// What [transcript] appears to describe.
  static VoiceExtraction read(VoiceTranscript transcript, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final words = _tokenise(transcript.text);
    final uncertain = <VoiceField>{};

    final type = _typeOf(words);
    if (type == null) uncertain.add(VoiceField.type);

    final amount = _amountIn(words);
    if (amount == null || amount <= 0) uncertain.add(VoiceField.amount);

    final match = _categoryIn(words, type ?? TransactionType.expense);
    if (match == null) uncertain.add(VoiceField.category);

    final when = _dateIn(words, today);
    if (when == null) uncertain.add(VoiceField.date);

    return VoiceExtraction(
      transcript: transcript,
      draft: TransactionDraft(
        type: type,
        magnitudeMinorUnits: amount,
        categoryId: match?.category.id,
        categoryLabel: match?.category.label,
        date: when ?? today,
        description: match?.description ?? '',
      ),
      uncertain: uncertain,
    );
  }

  // ------------------------------------------------------------- words

  static List<String> _tokenise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9,.\- ]'), ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  /// Verbs that say which way the money went.
  ///
  /// Kiswahili carries this in the verb — *nimetumia* (I spent),
  /// *nimepokea* (I received) — which is why the list is of verbs rather
  /// than of nouns.
  static const Set<String> _spent = {
    'nimetumia',
    'nimelipa',
    'nimelipia',
    'nimenunua',
    'nililipa',
    'nilitumia',
    'nimetoa',
    'spent',
    'spend',
    'paid',
    'pay',
    'bought',
    'buy',
  };

  static const Set<String> _received = {
    'nimepokea',
    'nimepata',
    'nimelipwa',
    'nimeuza',
    'nilipokea',
    'received',
    'receive',
    'earned',
    'earn',
    'got',
    'sold',
  };

  static TransactionType? _typeOf(List<String> words) {
    for (final word in words) {
      if (_spent.contains(word)) return TransactionType.expense;
      if (_received.contains(word)) return TransactionType.income;
    }
    return null;
  }

  // ----------------------------------------------------------- amounts

  static const Map<String, int> _units = {
    // Kiswahili
    'moja': 1,
    'mbili': 2,
    'tatu': 3,
    'nne': 4,
    'tano': 5,
    'sita': 6,
    'saba': 7,
    'nane': 8,
    'tisa': 9,
    'kumi': 10,
    'ishirini': 20,
    'thelathini': 30,
    'arobaini': 40,
    'hamsini': 50,
    'sitini': 60,
    'sabini': 70,
    'themanini': 80,
    'tisini': 90,
    // English
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  static const Map<String, int> _scales = {
    'mia': 100,
    'elfu': 1000,
    'laki': 100000,
    'milioni': 1000000,
    'hundred': 100,
    'thousand': 1000,
    'million': 1000000,
  };

  static const Set<String> _joiners = {'na', 'and'};

  /// The amount in minor units, or null when nothing was said.
  ///
  /// Handles both word orders without being told which language it is
  /// reading: Kiswahili puts the scale first — *elfu kumi*, thousand ten
  /// — and English puts it last — *ten thousand*. A pending scale covers
  /// the first case and a filled group covers the second.
  static int? _amountIn(List<String> words) {
    var total = 0;
    var group = 0;
    int? pendingScale;
    var sawNumber = false;

    void flush() {
      if (pendingScale != null) {
        total += (group == 0 ? 1 : group) * pendingScale!;
      } else {
        total += group;
      }
      group = 0;
      pendingScale = null;
    }

    for (final word in words) {
      final digits = _digitsIn(word);
      if (digits != null) {
        flush();
        total += digits;
        sawNumber = true;
        continue;
      }

      final unit = _units[word];
      if (unit != null) {
        group += unit;
        sawNumber = true;
        continue;
      }

      final scale = _scales[word];
      if (scale != null) {
        sawNumber = true;
        if (group > 0) {
          // "ten thousand"
          total += group * scale;
          group = 0;
          pendingScale = null;
        } else {
          // "elfu kumi" — the multiplier has not been said yet.
          if (pendingScale != null) total += pendingScale!;
          pendingScale = scale;
        }
        continue;
      }

      if (_joiners.contains(word)) continue;

      // Any other word ends the number being spoken.
      if (pendingScale != null || group > 0) flush();
    }

    flush();
    return sawNumber && total > 0 ? total : null;
  }

  static int? _digitsIn(String word) {
    final cleaned = word.replaceAll(',', '').replaceAll('.', '');
    if (cleaned.isEmpty || !RegExp(r'^\d+$').hasMatch(cleaned)) return null;
    return int.tryParse(cleaned);
  }

  // -------------------------------------------------------- categories

  /// Spoken words, and the category they belong to.
  ///
  /// The value is the category id; the word the user actually said
  /// becomes the description, so "nimenunua groceries" files under Food
  /// and still says "Groceries" in the list.
  static const Map<String, String> _categoryWords = {
    // Food
    'chakula': 'food',
    'chakula.': 'food',
    'food': 'food',
    'groceries': 'food',
    'manunuzi': 'shopping',
    'lunch': 'food',
    'chai': 'food',
    'mlo': 'food',
    'nyama': 'food',
    'mboga': 'food',
    // Transport
    'nauli': 'transport',
    'transport': 'transport',
    'bajaji': 'transport',
    'daladala': 'transport',
    'taxi': 'transport',
    'bodaboda': 'transport',
    'mafuta': 'transport',
    'fuel': 'transport',
    // Bills
    'umeme': 'bills',
    'electricity': 'bills',
    'maji': 'bills',
    'water': 'bills',
    'luku': 'bills',
    'bill': 'bills',
    'bills': 'bills',
    'internet': 'bills',
    'vocha': 'bills',
    'airtime': 'bills',
    // Housing
    'kodi': 'housing',
    'rent': 'housing',
    'nyumba': 'housing',
    // Health
    'dawa': 'health',
    'hospitali': 'health',
    'hospital': 'health',
    'health': 'health',
    'matibabu': 'health',
    // Education
    'ada': 'education',
    'shule': 'education',
    'school': 'education',
    'education': 'education',
    'books': 'education',
    // Shopping
    'nguo': 'shopping',
    'shopping': 'shopping',
    'clothes': 'shopping',
    // Entertainment
    'burudani': 'entertainment',
    'entertainment': 'entertainment',
    'cinema': 'entertainment',
    'sinema': 'entertainment',
    // Income
    'mshahara': 'salary',
    'salary': 'salary',
    'wages': 'salary',
    'biashara': 'business',
    'business': 'business',
    'freelance': 'freelance',
    'kazi': 'freelance',
    'zawadi': 'gift',
    'gift': 'gift',
  };

  static _CategoryMatch? _categoryIn(List<String> words, TransactionType type) {
    for (final word in words) {
      final id = _categoryWords[word];
      if (id == null) continue;

      final category = TransactionCategories.find(id, type);
      // A word from the other side of the ledger is not a match: "salary"
      // in a sentence about spending says nothing about the category.
      if (category == null) continue;

      final spoken = word[0].toUpperCase() + word.substring(1);
      return _CategoryMatch(
        category: category,
        // Only worth repeating when the user's word adds something the
        // category label does not already say.
        description: spoken.toLowerCase() == category.label.toLowerCase()
            ? ''
            : spoken,
      );
    }
    return null;
  }

  // -------------------------------------------------------------- dates

  static const Map<String, int> _daysAgo = {
    'leo': 0,
    'today': 0,
    'jana': 1,
    'yesterday': 1,
    'juzi': 2,
  };

  /// Words that name a day without naming which one.
  ///
  /// "Last week" is a real thing to say and an impossible thing to file,
  /// so the date is marked for review rather than quietly set to today.
  static const Set<String> _vagueDates = {
    'wiki',
    'mwezi',
    'week',
    'month',
    'ago',
    'iliyopita',
    'jumatatu',
    'jumanne',
    'jumatano',
    'alhamisi',
    'ijumaa',
    'jumamosi',
    'jumapili',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };

  static DateTime? _dateIn(List<String> words, DateTime today) {
    final midnight = DateTime(today.year, today.month, today.day);

    for (final word in words) {
      final ago = _daysAgo[word];
      if (ago != null) return midnight.subtract(Duration(days: ago));
    }

    for (final word in words) {
      if (_vagueDates.contains(word)) return null;
    }

    // Nothing about time was said at all, which almost always means now.
    return midnight;
  }
}

class _CategoryMatch {
  const _CategoryMatch({required this.category, required this.description});

  final TransactionCategory category;
  final String description;
}
