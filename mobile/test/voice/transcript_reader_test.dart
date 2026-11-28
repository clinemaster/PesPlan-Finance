import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/transactions/domain/transaction.dart';
import 'package:lifepilot_finance/features/voice/data/transcript_reader.dart';
import 'package:lifepilot_finance/features/voice/domain/voice_extraction.dart';
import 'package:lifepilot_finance/features/voice/domain/voice_language.dart';

final DateTime today = DateTime(2026, 11, 26, 15, 30);

VoiceExtraction read(
  String text, {
  VoiceLanguage language = VoiceLanguage.swahili,
}) => TranscriptReader.read(
  VoiceTranscript(text: text, language: language),
  today,
);

void main() {
  group('which way the money went', () {
    for (final sentence in [
      'Nimetumia shilingi elfu kumi kwa chakula',
      'Nimelipa elfu tano ya nauli',
      'Nimenunua groceries kwa elfu arobaini na tano',
      'I spent ten thousand shillings on food',
      'I paid five thousand for transport',
    ]) {
      test('"$sentence" is money out', () {
        expect(read(sentence).draft.type, TransactionType.expense);
      });
    }

    for (final sentence in [
      'Nimepokea mshahara wa milioni moja',
      'I received one million shillings as salary',
    ]) {
      test('"$sentence" is money in', () {
        expect(read(sentence).draft.type, TransactionType.income);
      });
    }

    test('a sentence with no verb leaves the side unknown', () {
      // Kiswahili carries the direction in the verb, so without one
      // there is nothing to read — and guessing "expense" because most
      // transactions are would be a guess about someone's money.
      final extraction = read('elfu kumi chakula');

      expect(extraction.draft.type, isNull);
      expect(extraction.isUncertainAbout(VoiceField.type), isTrue);
    });
  });

  group('amounts', () {
    for (final (sentence, expected) in [
      // Kiswahili puts the scale word first: "thousand ten" is 10,000.
      ('Nimetumia shilingi elfu kumi kwa chakula', 10000),
      ('Nimelipa elfu tano ya nauli', 5000),
      ('Leo nimelipia umeme shilingi elfu ishirini', 20000),
      ('Nimenunua groceries kwa elfu arobaini na tano', 45000),
      ('Nimepokea mshahara wa milioni moja', 1000000),
      ('Nimetumia laki mbili kwa kodi', 200000),
      ('Nimelipa mia tano ya chai', 500),
      // English puts it last.
      ('I spent ten thousand shillings on food', 10000),
      ('I paid five thousand for transport', 5000),
      ('I received one million shillings as salary', 1000000),
      ('I paid twenty thousand for electricity today', 20000),
      ('I spent forty-five thousand on groceries', 45000),
      // Digits, however they were written down.
      ('Nimetumia 10000 kwa chakula', 10000),
      ('I spent 45,000 on groceries', 45000),
    ]) {
      test('"$sentence" is $expected', () {
        expect(read(sentence).draft.magnitudeMinorUnits, expected);
      });
    }

    test('a sentence with no amount leaves it empty and marked', () {
      // The one field that must never be guessed: a wrong category is a
      // tap to fix, a wrong amount is wrong money.
      final extraction = read('Nimelipia umeme leo');

      expect(extraction.draft.magnitudeMinorUnits, isNull);
      expect(extraction.isUncertainAbout(VoiceField.amount), isTrue);
      expect(extraction.isReadyToSave, isFalse);
    });

    test('a correction changes the amount', () {
      // The whole point of letting someone edit the transcript.
      expect(
        read('Nimetumia elfu kumi kwa chakula').draft.magnitudeMinorUnits,
        10000,
      );
      expect(
        read('Nimetumia elfu ishirini kwa chakula').draft.magnitudeMinorUnits,
        20000,
      );
    });
  });

  group('categories', () {
    for (final (sentence, id) in [
      ('Nimetumia elfu kumi kwa chakula', 'food'),
      ('Nimelipa elfu tano ya nauli', 'transport'),
      ('Leo nimelipia umeme elfu ishirini', 'bills'),
      ('Nimelipa laki tatu ya kodi', 'housing'),
      ('Nimetumia elfu kumi kwa dawa', 'health'),
      ('I spent ten thousand on food', 'food'),
      ('I paid five thousand for transport', 'transport'),
      ('I paid twenty thousand for electricity', 'bills'),
    ]) {
      test('"$sentence" files under $id', () {
        expect(read(sentence).draft.categoryId, id);
      });
    }

    test('income words map to income categories', () {
      final extraction = read('Nimepokea mshahara wa milioni moja');

      expect(extraction.draft.categoryId, 'salary');
      expect(extraction.draft.type, TransactionType.income);
    });

    test('a category word from the wrong side is not used', () {
      // "Salary" in a sentence about spending says nothing about where
      // the money went.
      final extraction = read('Nimetumia elfu kumi kwa mshahara');

      expect(extraction.draft.categoryId, isNull);
      expect(extraction.isUncertainAbout(VoiceField.category), isTrue);
    });

    test('an unrecognised thing leaves the category for the user', () {
      final extraction = read('Nimetumia elfu kumi kwa kitu fulani');

      expect(extraction.draft.categoryId, isNull);
      expect(extraction.needsReview, contains(VoiceField.category));
    });

    test("the user's own word becomes the description", () {
      // "Groceries" is more use in the list than "Food", which the
      // category already says.
      final extraction = read('Nimenunua groceries kwa elfu arobaini');

      expect(extraction.draft.categoryLabel, 'Food');
      expect(extraction.draft.description, 'Groceries');
    });

    test('a word that only repeats the category is not a description', () {
      expect(read('I spent ten thousand on food').draft.description, '');
    });
  });

  group('dates', () {
    test('leo and today are today', () {
      expect(
        read('Leo nimelipia umeme elfu ishirini').draft.date,
        DateTime(2026, 11, 26),
      );
      expect(
        read('I paid twenty thousand for electricity today').draft.date,
        DateTime(2026, 11, 26),
      );
    });

    test('jana and yesterday are the day before', () {
      expect(
        read('Jana nimetumia elfu kumi kwa chakula').draft.date,
        DateTime(2026, 11, 25),
      );
      expect(
        read('Yesterday I spent ten thousand on food').draft.date,
        DateTime(2026, 11, 25),
      );
    });

    test('juzi is two days back', () {
      expect(
        read('Juzi nimelipa elfu tano ya nauli').draft.date,
        DateTime(2026, 11, 24),
      );
    });

    test('no mention of a day means today, and is not flagged', () {
      final extraction = read('Nimetumia elfu kumi kwa chakula');

      expect(extraction.draft.date, DateTime(2026, 11, 26));
      expect(extraction.isUncertainAbout(VoiceField.date), isFalse);
    });

    test('a day named but not pinned down is flagged, not assumed', () {
      // "Last week" is a real thing to say and an impossible thing to
      // file, so it is asked about rather than quietly filed as today.
      final extraction = read('Wiki iliyopita nimetumia elfu kumi kwa chakula');

      expect(extraction.isUncertainAbout(VoiceField.date), isTrue);
      expect(extraction.draft.date, DateTime(2026, 11, 26));
    });
  });

  group('the whole sentence', () {
    test('a complete one needs no review', () {
      final extraction = read('Nimetumia shilingi elfu kumi kwa chakula');

      expect(extraction.draft.type, TransactionType.expense);
      expect(extraction.draft.magnitudeMinorUnits, 10000);
      expect(extraction.draft.categoryId, 'food');
      expect(extraction.uncertain, isEmpty);
      expect(extraction.isReadyToSave, isTrue);
    });

    test('an incomplete one is never ready to save', () {
      for (final sentence in [
        'Nimelipia umeme leo',
        'elfu kumi chakula',
        'Nimetumia elfu kumi',
      ]) {
        expect(
          read(sentence).isReadyToSave,
          isFalse,
          reason: '"$sentence" should need review',
        );
      }
    });

    test('nothing at all is all unknown rather than a default transaction', () {
      final extraction = read('');

      expect(extraction.draft.type, isNull);
      expect(extraction.draft.magnitudeMinorUnits, isNull);
      expect(extraction.draft.categoryId, isNull);
      expect(extraction.isReadyToSave, isFalse);
    });

    test('a mixed-language sentence is read the same way', () {
      // Mixing English nouns into Kiswahili is the normal case in the
      // launch market, not an edge one.
      final extraction = read('Nimelipa elfu kumi kwa transport');

      expect(extraction.draft.type, TransactionType.expense);
      expect(extraction.draft.magnitudeMinorUnits, 10000);
      expect(extraction.draft.categoryId, 'transport');
    });

    test('amounts are positive magnitudes, whichever way the money went', () {
      // The sign is the type's job, exactly as on the form — a draft
      // never carries a signed amount.
      for (final sentence in [
        'Nimetumia elfu kumi kwa chakula',
        'Nimepokea mshahara wa milioni moja',
      ]) {
        expect(
          read(sentence).draft.magnitudeMinorUnits,
          greaterThan(0),
          reason: sentence,
        );
      }
    });
  });
}
