class VideoComment {
  const VideoComment({
    required this.username,
    required this.avatar,
    required this.text,
    required this.likes,
    this.reply,
  });
  final String username;
  final String avatar;
  final String text;
  final int likes;
  final VideoComment? reply;
}

class MockVideo {
  const MockVideo({
    required this.id,
    required this.username,
    required this.avatar,
    required this.caption,
    required this.videoUrl,
    required this.likes,
    required this.views,
    required this.comments,
    required this.linkedMarketId,
    required this.linkedMarketQuestion,
    required this.linkedMarketYesPrice,
    this.isAsset = false,
  });

  final String id;
  final String username;
  final String avatar;
  final String caption;
  final String videoUrl;
  final int likes;
  final int views;
  final List<VideoComment> comments;
  final String linkedMarketId;
  final String linkedMarketQuestion;
  final double linkedMarketYesPrice;
  final bool isAsset;
}
