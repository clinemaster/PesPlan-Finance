import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the provider SDK and the keystore behind their own files.
///
/// The same idea as `test/transactions/architecture_test.dart`, applied to a
/// different kind of leak. Both of these are easy to reach for from anywhere
/// — `GoogleSignIn.instance` is a global, and `FlutterSecureStorage()` is a
/// constructor away — and both are exactly what the auth feature's interfaces
/// exist to contain:
///
/// * A widget that calls the plugin directly cannot be tested without an
///   emulator, and it is how the sign-in flow ends up implemented twice.
/// * A credential written through a second `FlutterSecureStorage` instance
///   escapes the one place that knows the keys, the backup exclusion and the
///   read-failure handling.
///
/// The check is a text scan, so it is defeatable by anyone determined. It is
/// not there to stop malice; it is there so the next person adding a screen
/// finds out at `flutter test` rather than in review.
void main() {
  Iterable<File> dartFiles() =>
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

  test('only the client file touches the Google SDK', () {
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final name = file.uri.pathSegments.last;
      if (name == 'google_sign_in_client.dart') continue;

      for (final line in file.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('//') || code.startsWith('///')) continue;

        // Importing the package for its exception type is fine — the
        // repository has to name what it is mapping. Reaching for the
        // singleton is not.
        if (code.contains('GoogleSignIn.instance')) {
          offenders.add('${file.path}  $code');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only google_sign_in_client.dart may drive the plugin directly; '
          'everything else goes through GoogleSignInClient.\n\n'
          '${offenders.join('\n')}',
    );
  });

  test('only the credential store touches flutter_secure_storage', () {
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final name = file.uri.pathSegments.last;
      if (name == 'credential_store.dart') continue;

      for (final line in file.readAsLinesSync()) {
        if (line.contains('flutter_secure_storage') ||
            line.contains('FlutterSecureStorage')) {
          offenders.add('${file.path}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The keystore is reached through CredentialStore, which owns the '
          'keys, the read-failure handling and the backup exclusion that '
          'goes with them.\n\n${offenders.join('\n')}',
    );
  });

  test('no screen reads a credential', () {
    // A token on a widget is a token in a screenshot, a log line and a
    // crash report. The vault is data-layer only.
    final offenders = <String>[];

    for (final file in dartFiles()) {
      if (!file.path.contains('presentation')) continue;

      for (final line in file.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('//') || code.startsWith('///')) continue;

        if (code.contains('CredentialVault') ||
            code.contains('readIdToken') ||
            code.contains('credentialStoreProvider')) {
          // The one legitimate mention: the provider that hands the store
          // to the repository, which lives with the other auth providers.
          if (file.uri.pathSegments.last == 'auth_providers.dart') continue;

          offenders.add('${file.path}  $code');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the Android manifest asks for the internet', () {
    // The debug manifest gets this from the Flutter tool, so a missing
    // permission here fails only in release — the worst place to find out.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('the secure store is excluded from Android backup', () {
    // An encrypted value restored onto a phone whose keystore cannot
    // decrypt it is worse than no value: it produces errors instead of a
    // sign-in prompt.
    for (final path in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final rules = File(path).readAsStringSync();
      expect(
        rules,
        contains('FlutterSecureStorage.xml'),
        reason: '$path no longer excludes the secure store',
      );
    }

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('@xml/backup_rules'));
    expect(manifest, contains('@xml/data_extraction_rules'));
  });
}
