import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/config/auth_config.dart';

void main() {
  group('which provider a build uses', () {
    test('a clone with nothing configured gets the mock', () {
      // The default has to run. A build that refuses to start until someone
      // provisions OAuth credentials is a build nobody can look at.
      expect(const AuthConfig().provider, SignInProvider.mock);
      expect(const AuthConfig().isMock, isTrue);
    });

    test('a client id turns on the real provider', () {
      const config = AuthConfig(
        serverClientId: '000-test.apps.googleusercontent.com',
      );

      expect(config.provider, SignInProvider.google);
      expect(config.isGoogleConfigured, isTrue);
    });

    test('an explicit request for the mock wins over a client id', () {
      // How the cancelled and failed states stay reviewable on a machine
      // that does have credentials.
      const config = AuthConfig(
        serverClientId: '000-test.apps.googleusercontent.com',
        requested: 'mock',
      );

      expect(config.provider, SignInProvider.mock);
    });

    test('an explicit request for Google wins without a client id', () {
      // The other supported way to configure Android: the identifiers come
      // from google-services.json, where Dart cannot see them.
      const config = AuthConfig(requested: 'google');

      expect(config.provider, SignInProvider.google);
    });

    test('an unrecognised request falls back to the client id', () {
      expect(
        const AuthConfig(requested: 'yes please').provider,
        SignInProvider.mock,
      );
      expect(
        const AuthConfig(requested: 'GOOGLE', serverClientId: 'x').provider,
        SignInProvider.google,
      );
    });
  });

  group('what gets handed to the plugin', () {
    test('an absent client id is null, not empty', () {
      // The plugin reads null as "take it from the platform configuration
      // file" and an empty string as a client id that happens to be empty.
      expect(const AuthConfig().serverClientIdOrNull, isNull);
      expect(const AuthConfig().iosClientIdOrNull, isNull);
    });

    test('a configured client id is passed through unchanged', () {
      const config = AuthConfig(
        serverClientId: '000-test.apps.googleusercontent.com',
        iosClientId: '111-ios.apps.googleusercontent.com',
      );

      expect(
        config.serverClientIdOrNull,
        '000-test.apps.googleusercontent.com',
      );
      expect(config.iosClientIdOrNull, '111-ios.apps.googleusercontent.com');
    });
  });
}
