/// Per-page OG/Twitter metadata for a shareable screen. Pass to
/// `setShareMetadata` (from `web_url.dart`) when entering a screen, and
/// `resetShareMetadata` when leaving (or set a new page's metadata).
///
/// Defined in a standalone file (not `web_url.dart` itself) so both the web
/// and io platform variants can import it without a circular dependency
/// through the conditional-export barrel.
class ShareMetadata {
  const ShareMetadata({
    required this.title,
    required this.ogTitle,
    required this.ogDescription,
    this.ogImage,
    this.ogUrl,
    this.twitterCard = 'summary_large_image',
    this.twitterTitle,
    this.twitterDescription,
    this.twitterImage,
  });

  /// Browser tab title (document.title).
  final String title;

  /// `<meta property="og:title">`.
  final String ogTitle;

  /// `<meta property="og:description">`.
  final String ogDescription;

  /// `<meta property="og:image">` — absolute URL. Falls back to the site
  /// default if null.
  final String? ogImage;

  /// `<meta property="og:url">` — canonical URL for this page.
  final String? ogUrl;

  /// `<meta name="twitter:card">` — defaults to summary_large_image.
  final String twitterCard;

  /// `<meta name="twitter:title">` — falls back to [ogTitle].
  final String? twitterTitle;

  /// `<meta name="twitter:description">` — falls back to [ogDescription].
  final String? twitterDescription;

  /// `<meta name="twitter:image">` — falls back to [ogImage].
  final String? twitterImage;
}
