class Leaderboard {
  final String id;
  final String name;
  final String? coverUrl;
  final String? playCount;
  final String? updateFrequency;
  final String source;

  const Leaderboard({
    required this.id,
    required this.name,
    this.coverUrl,
    this.playCount,
    this.updateFrequency,
    this.source = 'wy',
  });

  Leaderboard copyWith({
    String? id,
    String? name,
    String? coverUrl,
    String? playCount,
    String? updateFrequency,
    String? source,
  }) {
    return Leaderboard(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      playCount: playCount ?? this.playCount,
      updateFrequency: updateFrequency ?? this.updateFrequency,
      source: source ?? this.source,
    );
  }
}

class PlaylistTag {
  final String id;
  final String name;
  final String source;

  const PlaylistTag({
    required this.id,
    required this.name,
    this.source = 'wy',
  });
}

class PlaylistTagGroup {
  final String name;
  final List<PlaylistTag> tags;

  const PlaylistTagGroup({
    required this.name,
    required this.tags,
  });
}