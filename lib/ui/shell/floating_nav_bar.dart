import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/ui/core_ui.dart';

class NavItem {
  const NavItem(this.icon, this.label);

  final AppIconData icon;
  final String label;
}

// شريط تنقل زجاجي عائم بخانات متساوية:
// اضغط على خانة، أو مرّر إصبعك يمينًا ويسارًا فيتبعك المؤشر الأصفر وتتبدّل الصفحة
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  // أقصر وأعرض (مقتبس من مرجع المستخدم): نسبة الارتفاع للعرض ~0.15
  static const double _height = 58;
  static const double _pad = 5;

  // موضع المؤشر أثناء السحب (كسري)، وnull عند عدم السحب
  double? _drag;

  int get _count => widget.items.length;

  // في العربية الخانات تبدأ من اليمين: الخانة المرئية ≠ رقم الصفحة
  bool _rtl = false;
  int _visual(int logical) => _rtl ? _count - 1 - logical : logical;

  double _posFor(double x, double width) {
    final cell = (width - _pad * 2) / _count;
    return ((x - _pad) / cell - 0.5).clamp(0.0, _count - 1.0).toDouble();
  }

  void _select(int visualTarget) {
    final target = _visual(visualTarget); // نفس التحويل يعمل بالاتجاهين
    if (target == widget.index) return;
    HapticFeedback.selectionClick();
    widget.onChanged(target);
  }

  void _follow(double x, double width) {
    final pos = _posFor(x, width);
    setState(() => _drag = pos);
    _select(pos.round());
  }

  void _endDrag() {
    if (_drag != null) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    _rtl = Directionality.of(context) == TextDirection.rtl;
    final dark = AppColors.isDark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cell = (width - _pad * 2) / _count;
            final dragging = _drag != null;
            final pos = _drag ?? _visual(widget.index).toDouble();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _select(_posFor(d.localPosition.dx, width).round()),
              onHorizontalDragStart: (d) => _follow(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _follow(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: _endDrag,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Color(dark ? 0x55000000 : 0x14000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_height / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: _height,
                      decoration: BoxDecoration(
                        // زجاج أشف: يظهر ما خلفه أكثر
                        color: AppColors.surface
                            .withValues(alpha: dark ? 0.48 : 0.38),
                        borderRadius: BorderRadius.circular(_height / 2),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.65),
                          width: 1,
                        ),
                      ),
                      // الترتيب المرئي من اليسار دائمًا، والتحويل للعربية يتم أعلاه
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Stack(
                        children: [
                          // المؤشر الأصفر المنزلق
                          AnimatedPositioned(
                            duration: dragging
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            left: _pad + pos * cell,
                            top: _pad,
                            width: cell,
                            height: _height - _pad * 2,
                            // مؤشر أصفر خفيف بلا توهج
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.yellow
                                    .withValues(alpha: dark ? 0.22 : 0.42),
                                borderRadius: BorderRadius.circular(
                                  (_height - _pad * 2) / 2,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(_pad),
                            child: Row(
                              children: [
                                for (var i = 0; i < _count; i++)
                                  Expanded(
                                    child: Directionality(
                                      // النص داخل الخانة بلغة التطبيق
                                      textDirection: _rtl
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      child: _NavCell(
                                        item: widget.items[_visual(i)],
                                        selected: _visual(i) == widget.index,
                                        closeness: (1 - (pos - i).abs())
                                            .clamp(0.0, 1.0),
                                      ),
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
  const _NavCell({
    required this.item,
    required this.selected,
    required this.closeness,
  });

  final NavItem item;
  final bool selected;
  final double closeness; // قرب المؤشر من الخانة (0..1)

  @override
  Widget build(BuildContext context) {
    // المؤشر صار خفيفًا: المحدد أسود نهارًا وأصفر ليلًا حتى يبقى واضحًا
    final dark = AppColors.isDark;
    final idle = dark ? const Color(0xFFA19C92) : const Color(0xFF6B6B6B);
    final on = dark ? AppColors.yellow : AppColors.onYellow;
    final color = Color.lerp(idle, on, closeness)!;
    final active = closeness > 0.5;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 1 + 0.1 * closeness,
            child: AppIcon(
              item.icon,
              size: 24,
              color: color,
              strokeWidth: active ? 2.0 : 1.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
