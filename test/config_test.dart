import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/config.dart';

void main() {
  group('config constants', () {
    test('constants are defined correctly', () {
      expect(backendUrl, 'https://api.pulsmarket.tech');
      expect(factoryAddress, '0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b');
      expect(appBaseUrl, 'https://pulsmarket.tech');
      expect(appUrl, 'https://app.pulsmarket.tech');
    });
  });

  group('proxifyImageUrl', () {
    test('returns empty string unchanged', () {
      expect(proxifyImageUrl(''), '');
    });

    test('returns backend URLs unchanged', () {
      expect(
        proxifyImageUrl('https://api.pulsmarket.tech/images/avatar.png'),
        'https://api.pulsmarket.tech/images/avatar.png',
      );
      expect(
        proxifyImageUrl('https://api.pulsmarket.tech'),
        'https://api.pulsmarket.tech',
      );
    });

    test('returns asset paths unchanged', () {
      expect(
        proxifyImageUrl('assets/images/logo.png'),
        'assets/images/logo.png',
      );
      expect(
        proxifyImageUrl('assets/icons/check.svg'),
        'assets/icons/check.svg',
      );
    });

    test('returns localhost URLs unchanged', () {
      expect(
        proxifyImageUrl('http://localhost:8080/test.png'),
        'http://localhost:8080/test.png',
      );
      expect(
        proxifyImageUrl('http://localhost/image.jpeg'),
        'http://localhost/image.jpeg',
      );
    });

    test('proxies external URLs through the image-proxy endpoint', () {
      const externalUrl = 'https://example.com/image.png';
      expect(
        proxifyImageUrl(externalUrl),
        'https://api.pulsmarket.tech/api/image-proxy?url=https%3A%2F%2Fexample.com%2Fimage.png',
      );
    });

    test('correctly URI-encodes external URLs', () {
      const externalUrlWithQuery =
          'https://example.com/path?foo=bar&baz=123#header';
      final expectedEncoded = Uri.encodeComponent(externalUrlWithQuery);
      expect(
        proxifyImageUrl(externalUrlWithQuery),
        'https://api.pulsmarket.tech/api/image-proxy?url=$expectedEncoded',
      );
      expect(
        proxifyImageUrl(externalUrlWithQuery),
        'https://api.pulsmarket.tech/api/image-proxy?url=https%3A%2F%2Fexample.com%2Fpath%3Ffoo%3Dbar%26baz%3D123%23header',
      );
    });
  });
}
