// lib/services/link_preview_service.dart
// Detects a URL in a chat message and fetches a lightweight link preview
// (title/description/image) by scraping Open Graph / <title> meta tags
// from the page's HTML — no new dependency, just the `http` package
// already in pubspec.yaml. Results are cached in-memory per URL for the
// life of the app session so reopening a conversation (or any rebuild of
// the message list) never refetches the same link twice.

import 'dart:async';
import 'package:http/http.dart' as http;

class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  const LinkPreviewData({required this.url, this.title, this.description, this.imageUrl});
}

class LinkPreviewService {
  LinkPreviewService._();
  static final LinkPreviewService instance = LinkPreviewService._();

  static final RegExp _urlPattern =
      RegExp(r'((https?:\/\/)[^\s<>"]+)', caseSensitive: false);

  /// url -> preview (null value means "fetched but nothing usable found",
  /// still cached so a link with no OG tags isn't retried every rebuild).
  final Map<String, LinkPreviewData?> _cache = {};
  final Map<String, Future<LinkPreviewData?>> _inFlight = {};

  /// First http(s) URL found in free-text message body, or null.
  String? firstUrl(String text) => _urlPattern.firstMatch(text)?.group(0);

  Future<LinkPreviewData?> fetch(String url) {
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = _fetchUncached(url);
    _inFlight[url] = future;
    return future;
  }

  Future<LinkPreviewData?> _fetchUncached(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; AcademiaLinkPreview/1.0)',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 400) {
        _cache[url] = null;
        return null;
      }
      final html = resp.body;
      final data = LinkPreviewData(
        url: url,
        title: _meta(html, 'og:title') ?? _tagText(html, 'title'),
        description: _meta(html, 'og:description') ?? _meta(html, 'description'),
        imageUrl: _meta(html, 'og:image'),
      );
      final usable = (data.title ?? '').isNotEmpty || (data.imageUrl ?? '').isNotEmpty;
      _cache[url] = usable ? data : null;
      return _cache[url];
    } catch (_) {
      _cache[url] = null;
      return null;
    } finally {
      _inFlight.remove(url);
    }
  }

  String? _meta(String html, String property) {
    for (final re in [
      RegExp('<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']*)["\']',
          caseSensitive: false),
      RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']$property["\']',
          caseSensitive: false),
    ]) {
      final m = re.firstMatch(html);
      if (m != null) return _unescape(m.group(1)!.trim());
    }
    return null;
  }

  String? _tagText(String html, String tag) {
    final m = RegExp('<$tag[^>]*>([^<]*)</$tag>', caseSensitive: false).firstMatch(html);
    return m != null ? _unescape(m.group(1)!.trim()) : null;
  }

  String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
