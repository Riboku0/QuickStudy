import 'package:flutter/foundation.dart';

import '../../services/reading_stats_service.dart';

// وقت القراءة لكل يوم (يُسجَّل عند إغلاق العارض) وعدد الجلسات.
// منه تُحسب أرقام الرئيسية: اليوم، آخر 7 أيام، المجموع، الأيام المتتالية.
class ReadingStatsRepository extends ChangeNotifier {
  ReadingStatsRepository({required ReadingStatsService service})
      : _service = service;

  final ReadingStatsService _service;

  final Map<String, int> _days = {}; // yyyy-mm-dd → ثوانٍ
  int _sessions = 0;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get sessions => _sessions;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> load() async {
    final data = await _service.read();
    final days = data['days'];
    if (days is Map) {
      for (final MapEntry(:key, :value) in days.entries) {
        if (key is String && value is num) _days[key] = value.toInt();
      }
    }
    final sessions = data['sessions'];
    _sessions = sessions is num ? sessions.toInt() : 0;
    _loaded = true;
    notifyListeners();
  }

  // جلسة قراءة انتهت. الجلسات القصيرة جدًا (فتح ثم رجوع) لا تُحسب
  Future<void> addSession(Duration duration) async {
    final seconds = duration.inSeconds;
    if (seconds < 5) return;
    final key = _key(_today());
    _days[key] = (_days[key] ?? 0) + seconds;
    _sessions++;
    notifyListeners();
    try {
      await _service.write({'days': _days, 'sessions': _sessions});
    } catch (_) {
      // فشل الحفظ لا يمنع عرض الرقم في هذه الجلسة
    }
  }

  int get todaySeconds => _days[_key(_today())] ?? 0;

  int get totalSeconds => _days.values.fold(0, (a, b) => a + b);

  // آخر 7 أيام، الأقدم أولًا (اليوم آخرها)
  List<(DateTime, int)> get lastWeek {
    final today = _today();
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          return (day, _days[_key(day)] ?? 0);
        }(),
    ];
  }

  int get weekSeconds => lastWeek.fold(0, (a, d) => a + d.$2);

  // أيام متتالية فيها قراءة حتى اليوم (أو حتى أمس إن لم يُقرأ اليوم بعد)
  int get streakDays {
    var day = _today();
    if ((_days[_key(day)] ?? 0) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    while ((_days[_key(day)] ?? 0) > 0) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get activeDays => _days.values.where((s) => s > 0).length;
}
