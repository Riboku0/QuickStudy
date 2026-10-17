import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'home_page.dart';
import 'study_page.dart';
import 'library_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Color background = Color(0xFFF3EFE6);
  static const Color dark = Color(0xFF202020);
  static const Color yellow = Color(0xFFFFD84D);

  int selectedIndex = 0;

  final pages = const [
    HomePage(),
    StudyPage(),
    LibraryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // الثيم أصبح في lib/theme/app_theme.dart
      theme: AppTheme.light(),
      home: Scaffold(
        extendBody: true,
        backgroundColor: background,
        // IndexedStack يحافظ على حالة كل صفحة عند التنقل
        body: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: _FloatingNavBar(
          index: selectedIndex,
          onChanged: (index) => setState(() => selectedIndex = index),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

// شريط تنقل زجاجي شفاف بخانات متساوية:
// اضغط على خانة، أو مرّر إصبعك يمينًا ويسارًا فيتبعك المؤشر وتتبدّل الصفحة
class _FloatingNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FloatingNavBar({
    required this.index,
    required this.onChanged,
  });

  static const Color dark = Color(0xFF202020);
  static const Color yellow = Color(0xFFFFD84D);

  static const List<_NavItem> items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.school_outlined, Icons.school_rounded, 'Study'),
    _NavItem(
      Icons.library_books_outlined,
      Icons.library_books_rounded,
      'Library',
    ),
  ];

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar> {
  static const double _height = 68;
  static const double _pad = 6;

  // موضع المؤشر أثناء السحب (كسري: 0 .. عدد العناصر-1)، وnull عند عدم السحب
  double? _drag;

  int get _count => _FloatingNavBar.items.length;

  double _posFor(double x, double width) {
    final cell = (width - _pad * 2) / _count;
    return ((x - _pad) / cell - 0.5).clamp(0.0, _count - 1.0).toDouble();
  }

  void _follow(double x, double width) {
    final pos = _posFor(x, width);
    final target = pos.round();

    setState(() => _drag = pos);

    // تبديل الصفحة مباشرة عند عبور المؤشر إلى خانة جديدة
    if (target != widget.index) {
      HapticFeedback.selectionClick();
      widget.onChanged(target);
    }
  }

  void _endDrag() {
    if (_drag != null) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cell = (width - _pad * 2) / _count;
            final dragging = _drag != null;
            final pos = _drag ?? widget.index.toDouble();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final target = _posFor(details.localPosition.dx, width).round();

                if (target != widget.index) {
                  HapticFeedback.selectionClick();
                  widget.onChanged(target);
                }
              },
              onHorizontalDragStart: (d) => _follow(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _follow(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: _endDrag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_height / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: _height,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(_height / 2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // المؤشر المنزلق
                        AnimatedPositioned(
                          duration: dragging
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: _pad + pos * cell,
                          top: _pad,
                          width: cell,
                          height: _height - _pad * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _FloatingNavBar.yellow
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(
                                (_height - _pad * 2) / 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40FFD84D),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // الخانات المتساوية
                        Padding(
                          padding: const EdgeInsets.all(_pad),
                          child: Row(
                            children: [
                              for (var i = 0; i < _count; i++)
                                Expanded(
                                  child: _NavCell(
                                    item: _FloatingNavBar.items[i],
                                    // قرب المؤشر من هذه الخانة (0..1)
                                    closeness:
                                        (1 - (pos - i).abs()).clamp(0.0, 1.0),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final _NavItem item;
  final double closeness;

  const _NavCell({
    required this.item,
    required this.closeness,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      const Color(0xFF6B6B6B),
      _FloatingNavBar.dark,
      closeness,
    )!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
          scale: 1 + 0.12 * closeness,
          child: Icon(
            closeness > 0.5 ? item.activeIcon : item.icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: closeness > 0.5 ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}