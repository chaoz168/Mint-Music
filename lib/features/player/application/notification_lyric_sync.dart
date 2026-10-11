import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service_init.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/models/lyric_line.dart';
import 'desktop_lyric_controller.dart';
import 'lyric_controller.dart';
import 'playback_controller.dart';

/// 蓝牙歌词使用的歌词行。
///
/// 与桌面歌词共用同一套就绪判定([areLyricsReadyForSong]),但独立受
/// 「通知栏蓝牙歌词」开关控制,两个功能互不依赖、可单独开启。
final notificationLyricLinesProvider = Provider<List<LyricLine>>((ref) {
  final enabled = ref.watch(showLyricNotificationProvider);
  if (!enabled) return const [];
  final song = ref.watch(
    playbackControllerProvider.select((s) => s.currentSong),
  );
  final lyric = ref.watch(lyricControllerProvider);
  if (!areLyricsReadyForSong(song, lyric)) return const [];
  return lyric.lines;
});

/// 当前播放进度对应的歌词行下标。
///
/// 与 [desktopLyricActiveIndexProvider] 同一套收敛策略:
/// 只在「当前行真的变了」时才通知监听者,避免每 200ms 重复合成媒体项。
final notificationLyricActiveIndexProvider = Provider<int>((ref) {
  final enabled = ref.watch(showLyricNotificationProvider);
  if (!enabled) return -1;
  final lines = ref.watch(notificationLyricLinesProvider);
  if (lines.isEmpty) return -1;
  final positionMs = ref.watch(
    playbackControllerProvider.select((s) => s.position.inMilliseconds),
  );
  final index = lines.lastIndexWhere((line) => line.startTimeMs <= positionMs);
  // 进度早于第一行的起始时间时,仍然展示第一行。
  return index < 0 ? 0 : index;
});

/// 蓝牙歌词同步:把当前歌词行写入媒体通知的标题位。
///
/// 与洛雪音乐「通知栏显示歌词」同一机制——通知标题即 MediaSession
/// 元数据的 TITLE 键,蓝牙车载屏/耳机等设备读取该元数据即可显示歌词。
///
/// 行为约定:
/// - 歌词未就绪(切歌加载中/无歌词)或功能关闭时还原为歌名,不残留上一首;
/// - 暂停时保留最后一行(与洛雪一致),不影响已显示的蓝牙设备;
/// - 文本相同时不下发(副歌重复行),减少通知重绘。
class NotificationLyricSyncController extends StateNotifier<bool> {
  NotificationLyricSyncController(this._ref) : super(false);

  final Ref _ref;

  /// 上一次推送的文本,用于去重。
  String? _lastText;

  bool get _enabled => _ref.read(showLyricNotificationProvider);

  /// 开关变化:关闭时立即还原通知标题。
  void setEnabled(bool enabled) {
    state = enabled;
    if (!enabled) _push(null);
  }

  /// 歌词行数据变化(切歌/加载完成):行号由 activeIndex 驱动,
  /// 这里只处理「歌词变为不可用」的清空,避免残留上一首的歌词。
  void onLinesChanged() {
    if (!_enabled) return;
    if (_ref.read(notificationLyricActiveIndexProvider) < 0) _push(null);
  }

  /// 当前行变化:推送新歌词行。
  void onIndexChanged(int index) {
    if (!_enabled) return;
    if (index < 0) {
      _push(null);
      return;
    }
    final lines = _ref.read(notificationLyricLinesProvider);
    if (index >= lines.length) {
      _push(null);
      return;
    }
    _push(lines[index].plainText);
  }

  void _push(String? text) {
    if (text == _lastText) return;
    _lastText = text;
    try {
      audioHandler.updateLyricText(text);
    } on StateError {
      // AudioService 尚未初始化(启动早期),此时没有通知可更新。
    }
  }
}

final notificationLyricSyncProvider =
    StateNotifierProvider<NotificationLyricSyncController, bool>((ref) {
      final controller = NotificationLyricSyncController(ref);

      ref.listen(showLyricNotificationProvider, (_, next) {
        controller.setEnabled(next);
      });
      ref.listen(notificationLyricLinesProvider, (_, _) {
        controller.onLinesChanged();
      });
      ref.listen(notificationLyricActiveIndexProvider, (_, next) {
        controller.onIndexChanged(next);
      });

      ref.onDispose(controller.dispose);
      return controller;
    });
