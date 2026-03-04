import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/src/web/web_models.dart';

void main() {
  group('CacheLocation', () {
    test('has memory and localStorage values', () {
      expect(CacheLocation.values, hasLength(2));
      expect(CacheLocation.values, contains(CacheLocation.memory));
      expect(CacheLocation.values, contains(CacheLocation.localStorage));
    });

    test('name returns expected strings', () {
      expect(CacheLocation.memory.name, 'memory');
      expect(CacheLocation.localStorage.name, 'localStorage');
    });
  });

  group('CacheMode', () {
    test('has on, off, and cacheOnly values', () {
      expect(CacheMode.values, hasLength(3));
      expect(CacheMode.values, contains(CacheMode.on));
      expect(CacheMode.values, contains(CacheMode.off));
      expect(CacheMode.values, contains(CacheMode.cacheOnly));
    });

    test('name returns expected strings', () {
      expect(CacheMode.on.name, 'on');
      expect(CacheMode.off.name, 'off');
      expect(CacheMode.cacheOnly.name, 'cacheOnly');
    });
  });

  group('SpaClientOptions', () {
    test('constructs with required parameters only', () {
      const opts = SpaClientOptions(
        domain: 'example.auth0.com',
        clientId: 'abc123',
      );

      expect(opts.domain, 'example.auth0.com');
      expect(opts.clientId, 'abc123');
      expect(opts.redirectUri, isNull);
      expect(opts.audience, isNull);
      expect(opts.scopes, {'openid', 'profile', 'email'});
      expect(opts.cacheLocation, CacheLocation.memory);
      expect(opts.useRefreshTokens, false);
      expect(opts.leeway, isNull);
    });

    test('constructs with all parameters', () {
      const opts = SpaClientOptions(
        domain: 'tenant.us.auth0.com',
        clientId: 'xyz789',
        redirectUri: 'http://localhost:3000/callback',
        audience: 'https://api.example.com',
        scopes: {'openid', 'read:users'},
        cacheLocation: CacheLocation.localStorage,
        useRefreshTokens: true,
        leeway: 60,
      );

      expect(opts.domain, 'tenant.us.auth0.com');
      expect(opts.clientId, 'xyz789');
      expect(opts.redirectUri, 'http://localhost:3000/callback');
      expect(opts.audience, 'https://api.example.com');
      expect(opts.scopes, {'openid', 'read:users'});
      expect(opts.cacheLocation, CacheLocation.localStorage);
      expect(opts.useRefreshTokens, true);
      expect(opts.leeway, 60);
    });

    test('default scopes include openid, profile, email', () {
      const opts = SpaClientOptions(
        domain: 'd',
        clientId: 'c',
      );
      expect(opts.scopes, containsAll(['openid', 'profile', 'email']));
    });

    test('empty scopes set is allowed', () {
      const opts = SpaClientOptions(
        domain: 'd',
        clientId: 'c',
        scopes: {},
      );
      expect(opts.scopes, isEmpty);
    });
  });
}
