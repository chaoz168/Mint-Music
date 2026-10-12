import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/discover_repository.dart';
import '../domain/models/playlist.dart';
import '../domain/models/leaderboard.dart';
import '../../player/domain/models/song.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_types.dart';
import '../../settings/application/settings_providers.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  final manager = ref.watch(musicSourceManagerProvider);
  return DiscoverRepository(manager);
});

final discoverSourceIdProvider = StateProvider<String>((ref) => ref.read(defaultSourceIdProvider));

final discoverSupportedSourcesProvider = Provider<List<SourceInfo>>((ref) {
  final manager = ref.watch(musicSourceManagerProvider);
  return manager.getDiscoverSupportedSources();
});

final hotPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final sourceId = ref.watch(discoverSourceIdProvider);
  return repo.getHotPlaylists(sourceId: sourceId);
});

final hotSearchTagsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  return repo.getHotSearchTags();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final repo = ref.watch(discoverRepositoryProvider);
  return repo.search(query);
});

final playlistDetailProvider = StateNotifierProvider.family<PlaylistDetailNotifier, AsyncValue<Playlist?>, String>((ref, playlistId) {
  final repo = ref.watch(discoverRepositoryProvider);
  return PlaylistDetailNotifier(repo, playlistId);
});

/// 歌单/排行榜详情分页控制器：首屏拉第一页，滚动到底 loadMore() 追加。
class PlaylistDetailNotifier extends StateNotifier<AsyncValue<Playlist?>> {
  final DiscoverRepository _repo;
  final String playlistId;

  PlaylistDetailNotifier(this._repo, this.playlistId)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  static const _pageSize = 50;

  int _page = 1;
  bool _noMore = false;
  bool _loadingMore = false;
  final List<Song> _songs = [];
  Playlist? _base;

  bool get noMore => _noMore;
  bool get loadingMore => _loadingMore;

  /// 重新拉取第一页（切换源或下拉刷新时用）
  Future<void> fetch() async {
    _page = 1;
    _noMore = false;
    _loadingMore = false;
    _songs.clear();
    _base = null;
    state = const AsyncValue.loading();
    await _loadPage();
  }

  /// 加载下一页
  Future<void> loadMore() async {
    if (_loadingMore || _noMore) return;
    await _loadPage();
  }

  Future<void> _loadPage() async {
    _loadingMore = true;
    try {
      final playlist = await _repo.getPlaylistDetail(
        playlistId,
        page: _page,
        limit: _pageSize,
      );
      if (playlist == null) {
        state = AsyncValue.data(_base);
        _noMore = true;
        return;
      }

      // 保留元信息（标题/封面/总数），歌曲累积追加
      _base ??= playlist;
      _songs.addAll(playlist.songs);
      _base = _base!.copyWith(songs: List<Song>.from(_songs));
      state = AsyncValue.data(_base);

      if (playlist.songs.length < _pageSize ||
          _songs.length >= playlist.songCount) {
        _noMore = true;
      } else {
        _page++;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _loadingMore = false;
    }
  }
}

final playlistTagsProvider = FutureProvider<List<PlaylistTagGroup>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final sourceId = ref.watch(discoverSourceIdProvider);
  return repo.getPlaylistTags(sourceId: sourceId);
});

final hotPlaylistTagsProvider = FutureProvider<List<PlaylistTag>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final sourceId = ref.watch(discoverSourceIdProvider);
  return repo.getHotPlaylistTags(sourceId: sourceId);
});

final activeTagIdProvider = StateProvider<String>((ref) => '');

final activeCategoryNameProvider = StateProvider<String>((ref) => '热门');

final categoryPlaylistsPageProvider = StateProvider<int>((ref) => 1);

final categoryPlaylistsProvider = StateNotifierProvider<CategoryPlaylistsNotifier, AsyncValue<List<Playlist>>>((ref) {
  final repo = ref.watch(discoverRepositoryProvider);
  return CategoryPlaylistsNotifier(repo);
});

class CategoryPlaylistsNotifier extends StateNotifier<AsyncValue<List<Playlist>>> {
  final DiscoverRepository _repo;

  CategoryPlaylistsNotifier(this._repo) : super(const AsyncValue.loading());

  int _page = 1;
  bool _noMore = false;
  bool _loadingMore = false;

  bool get noMore => _noMore;
  bool get loadingMore => _loadingMore;

  Future<void> fetchPlaylists({
    required String sortId,
    required String tagId,
    String? sourceId,
    bool reset = false,
  }) async {
    if (_loadingMore) return;

    if (reset) {
      _page = 1;
      _noMore = false;
      state = const AsyncValue.loading();
    }

    _loadingMore = true;
    try {
      final playlists = await _repo.getCategoryPlaylists(
        sortId: sortId,
        tagId: tagId,
        page: _page,
        limit: 30,
        sourceId: sourceId ?? 'wy',
      );

      if (reset) {
        state = AsyncValue.data(playlists);
      } else {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, ...playlists]);
      }

      if (playlists.length < 30) {
        _noMore = true;
      } else {
        _page++;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _loadingMore = false;
    }
  }
}

final leaderboardsProvider = FutureProvider<List<Leaderboard>>((ref) async {
  final repo = ref.watch(discoverRepositoryProvider);
  final sourceId = ref.watch(discoverSourceIdProvider);
  return repo.getLeaderboards(sourceId: sourceId);
});

enum DiscoverTab { playlists, leaderboards }

final discoverTabProvider = StateProvider<DiscoverTab>((ref) => DiscoverTab.playlists);