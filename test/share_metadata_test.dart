import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/share_metadata.dart';

ShareMetadata _shareMetadata({
  String title = 'Default Title',
  String ogTitle = 'Default OG Title',
  String ogDescription = 'Default OG Description',
  String? ogImage,
  String? ogUrl,
  String twitterCard = 'summary_large_image',
  String? twitterTitle,
  String? twitterDescription,
  String? twitterImage,
}) {
  return ShareMetadata(
    title: title,
    ogTitle: ogTitle,
    ogDescription: ogDescription,
    ogImage: ogImage,
    ogUrl: ogUrl,
    twitterCard: twitterCard,
    twitterTitle: twitterTitle,
    twitterDescription: twitterDescription,
    twitterImage: twitterImage,
  );
}

void main() {
  group('ShareMetadata', () {
    test('construction with all required fields preserves values', () {
      const metadata = ShareMetadata(
        title: 'Puls Market Title',
        ogTitle: 'OG Market Title',
        ogDescription: 'OG Market Description',
      );

      expect(metadata.title, 'Puls Market Title');
      expect(metadata.ogTitle, 'OG Market Title');
      expect(metadata.ogDescription, 'OG Market Description');
    });

    test('optional fields default to null', () {
      const metadata = ShareMetadata(
        title: 'Title',
        ogTitle: 'OG Title',
        ogDescription: 'OG Description',
      );

      expect(metadata.ogImage, isNull);
      expect(metadata.ogUrl, isNull);
      expect(metadata.twitterTitle, isNull);
      expect(metadata.twitterDescription, isNull);
      expect(metadata.twitterImage, isNull);
    });

    test('twitterCard defaults to summary_large_image', () {
      const metadata = ShareMetadata(
        title: 'Title',
        ogTitle: 'OG Title',
        ogDescription: 'OG Description',
      );

      expect(metadata.twitterCard, 'summary_large_image');
    });

    test('construction with all optional fields preserves them', () {
      const metadata = ShareMetadata(
        title: 'Custom Title',
        ogTitle: 'Custom OG Title',
        ogDescription: 'Custom OG Description',
        ogImage: 'https://puls.app/images/og.png',
        ogUrl: 'https://puls.app/market/123',
        twitterCard: 'summary',
        twitterTitle: 'Custom Twitter Title',
        twitterDescription: 'Custom Twitter Description',
        twitterImage: 'https://puls.app/images/twitter.png',
      );

      expect(metadata.title, 'Custom Title');
      expect(metadata.ogTitle, 'Custom OG Title');
      expect(metadata.ogDescription, 'Custom OG Description');
      expect(metadata.ogImage, 'https://puls.app/images/og.png');
      expect(metadata.ogUrl, 'https://puls.app/market/123');
      expect(metadata.twitterCard, 'summary');
      expect(metadata.twitterTitle, 'Custom Twitter Title');
      expect(metadata.twitterDescription, 'Custom Twitter Description');
      expect(metadata.twitterImage, 'https://puls.app/images/twitter.png');
    });

    test('multiple instances are independent (no shared state)', () {
      final instance1 = _shareMetadata(
        title: 'Market 1',
        ogTitle: 'OG 1',
        ogImage: 'https://puls.app/img1.png',
        twitterCard: 'summary',
      );

      final instance2 = _shareMetadata(
        title: 'Market 2',
        ogTitle: 'OG 2',
        ogImage: 'https://puls.app/img2.png',
        twitterCard: 'summary_large_image',
      );

      expect(instance1.title, 'Market 1');
      expect(instance1.ogTitle, 'OG 1');
      expect(instance1.ogImage, 'https://puls.app/img1.png');
      expect(instance1.twitterCard, 'summary');

      expect(instance2.title, 'Market 2');
      expect(instance2.ogTitle, 'OG 2');
      expect(instance2.ogImage, 'https://puls.app/img2.png');
      expect(instance2.twitterCard, 'summary_large_image');
    });
  });
}
