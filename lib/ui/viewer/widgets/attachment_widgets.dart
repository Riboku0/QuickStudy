import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/ui/core_ui.dart';
import 'reader_chrome.dart';

// مدة التسجيل القصوى (اختيار المستخدم: حتى 10 دقائق)
const Duration maxRecording = Duration(minutes: 10);

String formatClip(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

// ---------------------------------------------------------------------------
// لوحة التسجيل: زر كبير يبدأ ويوقف، عداد، ومؤشر صوت. ترجع مدة التسجيل بعد
// حفظه في path، أو null عند الإلغاء (والملف يُحذف). تتوقف وحدها عند 10 دقائق.
// ---------------------------------------------------------------------------
Future<Duration?> showRecordSheet(
  BuildContext context, {
  required ReaderChrome chrome,
  required String path,
}) {
  return showModalBottomSheet<Duration>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordSheet(chrome: chrome, path: path),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({required this.chrome, required this.path});

  final ReaderChrome chrome;
  final String path;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _tick;
  StreamSubscription<Amplitude>? _level;
  double _amp = 0; // 0..1
  bool _recording = false;
  bool _done = false;

  @override
  void dispose() {
    _tick?.cancel();
    _level?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final s = AppStrings.of(context);
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      showAppMessage(context, s.micDenied, tone: MessageTone.error);
      Navigator.of(context).pop();
      return;
    }
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: widget.path,
    );
    _watch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_watch.elapsed >= maxRecording) {
        _stop();
        return;
      }
      setState(() {});
    });
    _level = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((a) {
          // dBFS من -45 (هدوء) إلى 0
          final v = ((a.current + 45) / 45).clamp(0.0, 1.0);
          if (mounted) setState(() => _amp = v);
        });
    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    if (_done) return;
    _done = true;
    _tick?.cancel();
    _watch.stop();
    await _recorder.stop();
    if (mounted) Navigator.of(context).pop(_watch.elapsed);
  }

  Future<void> _cancel() async {
    _done = true;
    _tick?.cancel();
    if (_recording) await _recorder.cancel(); // يحذف الملف
    try {
      final f = File(widget.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;
    final left = maxRecording - _watch.elapsed;

    return Container(
      // فوق أزرار أندرويد (شريط الحالة مخفي فالمساحة الآمنة صفر)
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _recording ? s.recordingNow : s.tapToRecord,
            style: TextStyle(
              color: c.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _recording
                ? '${formatClip(_watch.elapsed)}  /  ${formatClip(maxRecording)}'
                : s.recordLimit,
            style: TextStyle(
              color: _recording && left.inSeconds < 30 ? c.strong : c.muted,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          // الزر: دائرة بلون الثيم تنبض مع مستوى الصوت
          Semantics(
            button: true,
            label: _recording ? s.done : s.recordAudio,
            child: GestureDetector(
              onTap: _recording ? _stop : _start,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 84,
                height: 84,
                padding: EdgeInsets.all(10 - 8 * _amp),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.strong,
                  ),
                  child: Center(
                    child: AppIcon(
                      _recording ? AppIcons.stop : AppIcons.mic,
                      size: 30,
                      color: c.onStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _cancel,
            child: Text(s.cancel, style: TextStyle(color: c.muted)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط التشغيل أسفل العارض: تشغيل/إيقاف، شريط تقدم يُسحب، المدة، وإغلاق.
// يبدأ التشغيل فورًا، ويُغلق وحده عند نهاية المقطع.
// ---------------------------------------------------------------------------
class AttachmentPlayerBar extends StatefulWidget {
  const AttachmentPlayerBar({
    super.key,
    required this.path,
    required this.chrome,
    required this.onClose,
  });

  final String path;
  final ReaderChrome chrome;
  final VoidCallback onClose;

  @override
  State<AttachmentPlayerBar> createState() => _AttachmentPlayerBarState();
}

class _AttachmentPlayerBarState extends State<AttachmentPlayerBar> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _state;
  double? _dragging; // موضع السحب (0..1) قبل الإفلات

  @override
  void initState() {
    super.initState();
    _state = _player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) widget.onClose();
    });
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setFilePath(widget.path);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      showAppMessage(
        context,
        AppStrings.of(context).attachFailed,
        tone: MessageTone.error,
      );
      widget.onClose();
    }
  }

  @override
  void dispose() {
    _state?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = widget.chrome;

    return Material(
      color: c.surface,
      elevation: 10,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
        child: StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snap) {
            final total = _player.duration ?? Duration.zero;
            final pos = snap.data ?? Duration.zero;
            final ms = total.inMilliseconds;
            final value =
                _dragging ??
                (ms == 0 ? 0.0 : (pos.inMilliseconds / ms).clamp(0.0, 1.0));
            return Row(
              children: [
                StreamBuilder<bool>(
                  stream: _player.playingStream,
                  builder: (context, playing) {
                    final on = playing.data ?? false;
                    return IconButton(
                      tooltip: on ? s.pause : s.play,
                      onPressed: on ? _player.pause : _player.play,
                      icon: AppIcon(
                        on ? AppIcons.pause : AppIcons.play,
                        size: 22,
                        color: c.strong,
                      ),
                    );
                  },
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: c.strong,
                      inactiveTrackColor: c.accent,
                      thumbColor: c.strong,
                      overlayColor: c.accent,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      onChanged: (v) => setState(() => _dragging = v),
                      onChangeEnd: (v) {
                        _player.seek(total * v);
                        setState(() => _dragging = null);
                      },
                    ),
                  ),
                ),
                Text(
                  '${formatClip(pos)} / ${formatClip(total)}',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  tooltip: s.closePlayer,
                  onPressed: widget.onClose,
                  icon: AppIcon(AppIcons.close, size: 19, color: c.ink),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الصورة بملء الشاشة: خلفية سوداء، تكبير بالإصبعين، وزر إغلاق
// ---------------------------------------------------------------------------
Future<void> showImageFullScreen(BuildContext context, String path) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) {
        final s = AppStrings.of(context);
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image.file(File(path))),
                ),
              ),
              PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + 8,
                end: 8,
                child: IconButton(
                  tooltip: s.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: AppIcon(AppIcons.close, size: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
