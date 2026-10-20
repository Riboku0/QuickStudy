import 'package:flutter/foundation.dart';

import '../../services/reading_stats_service.dart';

// وقت القراءة لكل يوم (يُسجَّل عند إغلاق العارض) وعدد الجلسات،
// وعدادات يومية: الصفحات المقروءة، البطاقات المراجعة، الأسئلة المحلولة.
// منه تُحسب أرقام الرئيسية: اليوم، آخر 7 أيام، المجموع، الأيام المتتالية.
class ReadingStatsRepository extends ChangeNotifier {
  ReadingStatsRepository({required ReadingStatsService service})
      : _service = service;

  final ReadingStatsService _service;

  final Map<String, int> _days = {}; // yyyy-mm-dd → ثوانٍ
  final Map<String, int> _pages = {}; // yyyy-mm-dd → صفحات
  final Map<String, int> _cards = {}; // yyyy-mm-dd → بطاقات
  final Map<String, int> _questions = {}; // yyyy-mm-dd → أسئلة
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

  static void _readMap(Object? source, Map<String, int> into) {
    if (source is! Map) return;
    for (final MapEntry(:key, :value) in source.entries) {
      if (key is String && value is num) into[key] = value.toInt();
    }
  }

  Future<void> load() async {
    final data = await _service.read();
    _readMap(data['days'], _days);
    _readMap(data['pages'], _pages);
    _readMap(data['cards'], _cards);
    _readMap(data['questions'], _questions);
    final sessions = data['sessions'];
    _sessions = sessions is num ? sessions.toInt() : 0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _service.write({
        'days': _days,
        'sessions': _sessions,
        'pages': _pages,
        'cards': _cards,
        'questions': _questions,
      });
    } catch (_) {
      // فشل الحفظ لا يمنع عرض الرقم في هذه الجلسة
    }
  }

  // جلسة قراءة انتهت. الجلسات القصيرة جدًا (فتح ثم رجوع) لا تُحسب.
  // pages: عدد الصفحات المختلفة التي مرّ بها القارئ في الجلسة
  Future<void> addSession(Duration duration, {int pages = 0}) async {
    final seconds = duration.inSeconds;
    if (seconds < 5) return;
    final key = _key(_today());
    _days[key] = (_days[key] ?? 0) + seconds;
    if (pages > 0) _pages[key] = (_pages[key] ?? 0) + pages;
    _sessions++;
    notifyListeners();
    await _save();
  }

  // بطاقة روجعت (من شاشة البطاقات)
  Future<void> addCards(int n) => _bump(_cards, n);

  // سؤال أُجيب عنه (من شاشة الاختبار)
  Future<void> addQuestions(int n) => _bump(_questions, n);

  Future<void> _bump(Map<String, int> map, int n) async {
    if (n <= 0) return;
    final key = _key(_today());
    map[key] = (map[key] ?? 0) + n;
    notifyListeners();
    await _save();
  }

  int get todaySeconds => _days[_key(_today())] ?? 0;
  int get todayPages => _pages[_key(_today())] ?? 0;
  int get todayCards => _cards[_key(_today())] ?? 0;
  int get todayQuestions => _questions[_key(_today())] ?? 0;

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
