import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/blog_post.dart';

BlogAuthor _blogAuthor({
  String userId = 'author_123',
  String displayName = 'Jane Doe',
  String avatarUrl = 'https://example.com/avatar.png',
  bool isAgent = false,
}) =>
    BlogAuthor(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isAgent: isAgent,
    );

BlogSource _blogSource({
  String title = 'Example Source',
  String url = 'https://example.com/article',
  String? source = 'Tech Crunch',
}) =>
    BlogSource(
      title: title,
      url: url,
      source: source,
    );

BlogPost _blogPost({
  String id = 'post_123',
  String title = 'Understanding Prediction Markets',
  BlogAuthor? author,
  String? excerpt = 'An introduction to prediction markets.',
  String? body = '# Market Analysis\nDetailed content here...',
  String? coverUrl = 'https://example.com/cover.jpg',
  List<String> tags = const ['crypto', 'markets'],
  List<BlogSource> sources = const [],
  String kind = 'post',
  int views = 150,
  bool featured = false,
  DateTime? publishedAt,
}) =>
    BlogPost(
      id: id,
      title: title,
      author: author ?? _blogAuthor(),
      excerpt: excerpt,
      body: body,
      coverUrl: coverUrl,
      tags: tags,
      sources: sources,
      kind: kind,
      views: views,
      featured: featured,
      publishedAt: publishedAt ?? DateTime(2026, 8, 1, 10, 0, 0),
    );

void main() {
  group('BlogPost.fromJson', () {
    test('parses full JSON payload correctly', () {
      final json = {
        'id': 'post_999',
        'title': 'NYT Analysis: AI Trading',
        'author': {
          'userId': 'agent_007',
          'displayName': 'Alpha Agent',
          'avatarUrl': 'https://example.com/agent.png',
          'isAgent': true,
        },
        'excerpt': 'AI agents dominate market trades.',
        'body': 'Full analysis report...',
        'coverUrl': 'https://example.com/header.png',
        'tags': ['ai', 'trading', 'finance'],
        'sources': [
          {
            'title': 'Bloomberg Article',
            'url': 'https://bloomberg.com/news/1',
            'source': 'Bloomberg',
          },
        ],
        'kind': 'analysis',
        'views': 4200,
        'featured': true,
        'publishedAt': '2026-08-10T14:30:00.000Z',
      };

      final post = BlogPost.fromJson(json);

      expect(post.id, 'post_999');
      expect(post.title, 'NYT Analysis: AI Trading');
      expect(post.author.userId, 'agent_007');
      expect(post.author.displayName, 'Alpha Agent');
      expect(post.author.avatarUrl, 'https://example.com/agent.png');
      expect(post.author.isAgent, isTrue);
      expect(post.excerpt, 'AI agents dominate market trades.');
      expect(post.body, 'Full analysis report...');
      expect(post.coverUrl, 'https://example.com/header.png');
      expect(post.tags, equals(['ai', 'trading', 'finance']));
      expect(post.sources.length, 1);
      expect(post.sources.first.title, 'Bloomberg Article');
      expect(post.sources.first.url, 'https://bloomberg.com/news/1');
      expect(post.sources.first.source, 'Bloomberg');
      expect(post.kind, 'analysis');
      expect(post.views, 4200);
      expect(post.featured, isTrue);
      expect(post.publishedAt, DateTime.parse('2026-08-10T14:30:00.000Z'));
    });

    test('handles minimal/missing fields with proper defaults', () {
      final post = BlogPost.fromJson(const {});

      expect(post.id, 'null');
      expect(post.title, '');
      expect(post.author.userId, '');
      expect(post.author.displayName, 'Puls Writer');
      expect(post.author.avatarUrl, '');
      expect(post.author.isAgent, isFalse);
      expect(post.excerpt, isNull);
      expect(post.body, isNull);
      expect(post.coverUrl, isNull);
      expect(post.tags, isEmpty);
      expect(post.sources, isEmpty);
      expect(post.kind, 'post');
      expect(post.views, 0);
      expect(post.featured, isFalse);
      expect(post.publishedAt, isNull);
    });

    test('defaults to empty BlogAuthor when author in JSON is null', () {
      final json = {'author': null};
      final post = BlogPost.fromJson(json);

      expect(post.author.userId, '');
      expect(post.author.displayName, 'Puls Writer');
      expect(post.author.avatarUrl, '');
      expect(post.author.isAgent, isFalse);
    });

    test('parses tags correctly including null and non-string elements', () {
      final jsonWithNullTags = {'tags': null};
      expect(BlogPost.fromJson(jsonWithNullTags).tags, isEmpty);

      final jsonWithMixedTags = {
        'tags': ['flutter', 123, true],
      };
      expect(
        BlogPost.fromJson(jsonWithMixedTags).tags,
        equals(['flutter', '123', 'true']),
      );
    });

    test('parses sources and filters out non-Map entries', () {
      final json = {
        'sources': [
          'invalid_string_entry',
          12345,
          null,
          {
            'title': 'Valid Source',
            'url': 'https://valid.com',
            'source': 'Valid Media',
          },
        ],
      };

      final post = BlogPost.fromJson(json);
      expect(post.sources.length, 1);
      expect(post.sources.first.title, 'Valid Source');
      expect(post.sources.first.url, 'https://valid.com');
    });

    test('parses views as num (int and double from JSON)', () {
      expect(BlogPost.fromJson(const {'views': 100}).views, 100);
      expect(BlogPost.fromJson(const {'views': 99.85}).views, 99);
      expect(BlogPost.fromJson(const {'views': null}).views, 0);
    });

    test('parses featured field correctly for true, false, and null', () {
      expect(BlogPost.fromJson(const {'featured': true}).featured, isTrue);
      expect(BlogPost.fromJson(const {'featured': false}).featured, isFalse);
      expect(BlogPost.fromJson(const {'featured': null}).featured, isFalse);
      expect(BlogPost.fromJson(const {'featured': 'true'}).featured, isFalse);
    });

    test('parses publishedAt date for valid ISO string, invalid, and null', () {
      const isoString = '2026-08-12T18:00:00.000Z';
      final validPost = BlogPost.fromJson(const {'publishedAt': isoString});
      expect(validPost.publishedAt, DateTime.parse(isoString));

      final invalidPost =
          BlogPost.fromJson(const {'publishedAt': 'not-a-valid-date'});
      expect(invalidPost.publishedAt, isNull);

      final nullPost = BlogPost.fromJson(const {'publishedAt': null});
      expect(nullPost.publishedAt, isNull);
    });
  });

  group('BlogPost getters', () {
    test('isAnalysis returns true when kind is "analysis" and false otherwise',
        () {
      expect(_blogPost(kind: 'analysis').isAnalysis, isTrue);
      expect(_blogPost(kind: 'post').isAnalysis, isFalse);
      expect(_blogPost(kind: 'news').isAnalysis, isFalse);
    });

    test('hasBody returns correct bool for null, empty string, and non-empty',
        () {
      expect(_blogPost(body: null).hasBody, isFalse);
      expect(_blogPost(body: '').hasBody, isFalse);
      expect(_blogPost(body: '   ').hasBody, isTrue);
      expect(_blogPost(body: 'Content present').hasBody, isTrue);
    });

    test('hasSources returns true when sources list is not empty', () {
      expect(_blogPost(sources: const []).hasSources, isFalse);
      expect(
        _blogPost(sources: [_blogSource()]).hasSources,
        isTrue,
      );
    });
  });

  group('BlogAuthor.fromJson', () {
    test('parses full JSON payload correctly', () {
      final json = {
        'userId': 'usr_555',
        'displayName': 'Alice Smith',
        'avatarUrl': 'https://example.com/alice.png',
        'isAgent': true,
      };

      final author = BlogAuthor.fromJson(json);
      expect(author.userId, 'usr_555');
      expect(author.displayName, 'Alice Smith');
      expect(author.avatarUrl, 'https://example.com/alice.png');
      expect(author.isAgent, isTrue);
    });

    test('applies proper default values for empty JSON payload', () {
      final author = BlogAuthor.fromJson(const {});
      expect(author.userId, '');
      expect(author.displayName, 'Puls Writer');
      expect(author.avatarUrl, '');
      expect(author.isAgent, isFalse);
    });
  });

  group('BlogSource.fromJson', () {
    test('follows title fallback chain (title -> source -> url -> "Source")',
        () {
      // 1. Explicit title provided
      final withTitle = BlogSource.fromJson(const {
        'title': 'Explicit Title',
        'source': 'Source Name',
        'url': 'https://example.com',
      });
      expect(withTitle.title, 'Explicit Title');

      // 2. Title missing, source provided
      final withSourceOnly = BlogSource.fromJson(const {
        'source': 'Source Name',
        'url': 'https://example.com',
      });
      expect(withSourceOnly.title, 'Source Name');

      // 3. Title & source missing, url provided
      final withUrlOnly = BlogSource.fromJson(const {
        'url': 'https://example.com',
      });
      expect(withUrlOnly.title, 'https://example.com');

      // 4. Title, source, and url all missing/null
      final emptySource = BlogSource.fromJson(const {});
      expect(emptySource.title, 'Source');
    });

    test('handles blank or whitespace-only title by falling back', () {
      // Whitespace title with source
      final wsWithSource = BlogSource.fromJson(const {
        'title': '   ',
        'source': 'WSJ',
        'url': 'https://wsj.com',
      });
      expect(wsWithSource.title, 'WSJ');

      // Blank title with url only
      final blankWithUrl = BlogSource.fromJson(const {
        'title': '',
        'url': 'https://news.com',
      });
      expect(blankWithUrl.title, 'https://news.com');

      // Whitespace title with no other fields
      final wsOnly = BlogSource.fromJson(const {
        'title': '    ',
      });
      expect(wsOnly.title, 'Source');
    });
  });
}
