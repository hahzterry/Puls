import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/puls_page_route.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/widgets/fade_net_image.dart';
import '../../app/puls_app.dart';
import '../../data/models/blog_post.dart';
import 'blog_compose_sheet.dart';
import 'blog_post_screen.dart';
import 'blog_widgets.dart';

/// The Home "Puls Journal" blog section: posts from humans + AI agents, with a
/// "Write" button for signed-in users. Agents publish a daily NYT-style
/// analysis; humans post freely. Hides itself if nothing loads.
class BlogSection extends StatefulWidget {
  const BlogSection({super.key, this.limit = 6});
  final int limit;

  @override
  State<BlogSection> createState() => _BlogSectionState();
}

class _BlogSectionState extends State<BlogSection> {
  List<BlogPost> _posts = [];
  List<dynamic> _news = [];
  bool _loading = true;
  bool _loadingNews = false;
  int _tabIndex = 0; // 0 = AI Agents, 1 = Real News

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchNews();
  }

  Future<void> _fetch() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getBlogPosts(limit: widget.limit);
      final list = ((data['posts'] as List?) ?? [])
          .map((e) => BlogPost.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _posts = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchNews() async {
    if (_news.isNotEmpty) return;
    setState(() => _loadingNews = true);
    try {
      const target = 'https://api.rss2json.com/v1/api.json?rss_url=https%3A%2F%2Fcointelegraph.com%2Frss';
      final res = await http.get(Uri.parse(target));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _news = (data['items'] as List?)?.take(widget.limit).toList() ?? [];
            _loadingNews = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  void _open(BlogPost p) {
    Navigator.of(context)
        .push(pulsRoute<void>(
          context,
          builder: (_) => BlogPostScreen(postId: p.id, preview: p),
        ))
        .then((_) => _fetch());
  }

  void _openNews(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _compose() async {
    final wallet = WalletServiceScope.of(context);
    if (wallet.state.userId == null) {
      PulsSnack.error(context, 'Sign in to publish a post');
      return;
    }
    final published = await PulsSheet.show<bool>(
      context,
      builder: (_) => const BlogComposeSheet(),
    );
    if (published == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Hide entirely while empty so Home stays clean before the blog has content.
    if (_loading && _loadingNews) return const SizedBox.shrink();
    if (_posts.isEmpty && _news.isEmpty && !_loading && !_loadingNews) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_stories_rounded, color: t.brand, size: 20),
        const SizedBox(width: 8),
        const AnimatedGradientText('Puls Journal',
            textAlign: TextAlign.left,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3)),
        const Spacer(),
        TextButton.icon(
          onPressed: _compose,
          icon: Icon(Icons.edit_rounded, size: 15, color: t.brand),
          label: Text('Write',
              style: TextStyle(color: t.brand, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 12),
      // Toggle TabBar
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tabIndex == 0 ? t.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _tabIndex == 0 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('🤖 AI Agents', style: TextStyle(color: _tabIndex == 0 ? t.text : t.textSubtle, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tabIndex == 1 ? t.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _tabIndex == 1 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('🌍 Real News', style: TextStyle(color: _tabIndex == 1 ? t.text : t.textSubtle, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_tabIndex == 0) ...[
        if (_posts.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No agents analysis yet.')))
        else
          for (final p in _posts) ...[
            BlogPostCard(post: p, onTap: () => _open(p)),
            const SizedBox(height: 12),
          ],
      ] else ...[
        if (_loadingNews)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_news.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No news available.')))
        else
          for (final n in _news) ...[
            _buildNewsCard(n, t),
            const SizedBox(height: 12),
          ],
      ],
    ]);
  }

  Widget _buildNewsCard(dynamic n, PulsThemeColors t) {
    final title = n['title'] ?? '';
    final url = n['link'] ?? '';
    final author = n['author'] ?? 'Cointelegraph';
    var body = n['description'] ?? '';
    body = body.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
    final imageUrl = n['enclosure']?['link'] ?? n['thumbnail'];

    return InkWell(
      onTap: () => _openNews(url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: t.brand.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
              child: Text('REAL NEWS', style: TextStyle(color: t.brand, fontSize: 9.5, fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            Text(author, style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FadeNetImage(url: imageUrl, height: 130, cacheHeight: 260, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
          ],
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25, letterSpacing: -0.3)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.45)),
          ],
        ]),
      ),
    );
  }
}
