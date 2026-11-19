import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'nav_item_data.dart';

/// Floating bottom navigation: a long rounded pill with a sliding green
/// "active" capsule, plus an optional separate circular action on the right.
final class FloatingPillNav extends StatefulWidget {
  const FloatingPillNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.trailingAction,
  });

  final List<NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget? trailingAction;

  static const double height = 64;

  @override
  State<FloatingPillNav> createState() => _FloatingPillNavState();
}

final class _FloatingPillNavState extends State<FloatingPillNav> {
  static const _green = Color(0xFF004741);
  static const _cream = Color(0xFFF0EDE4);
  static const _inactive = Color(0xFF5F6B68);
  static const _pad = 6.0;
  static const _slot = 56.0;
  static const _labelStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _cream,
  );

  void _select(int index) {
    if (index == widget.currentIndex) return;
    if (!kIsWeb) HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 350);
    final pill = SizedBox(
      height: FloatingPillNav.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F3),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFDAD5C7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2A27).withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inner = math.max(0.0, constraints.maxWidth - 2 * _pad);
            final count = widget.items.length;
            final active = widget.currentIndex.clamp(-1, count - 1);
            final others = (active < 0 ? count : count - 1) * _slot;
            final activeLabel = active < 0 ? '' : widget.items[active].label;
            var activeWidth = active < 0
                ? 0.0
                : 20 + 22 + 8 + _labelWidth(context, activeLabel) + 20;
            if (others + activeWidth > inner) {
              activeWidth = math.max(_slot, inner - others);
            }
            final used = others + activeWidth;
            final gap = count > 1
                ? math.max(0.0, (inner - used) / (count - 1))
                : 0.0;
            var x = _pad;
            final lefts = <double>[];
            final widths = <double>[];
            for (var i = 0; i < count; i++) {
              final w = i == active ? activeWidth : _slot;
              lefts.add(x);
              widths.add(w);
              x += w + gap;
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (active >= 0)
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: lefts[active],
                    width: widths[active],
                    top: _pad,
                    height: FloatingPillNav.height - 2 * _pad,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                    ),
                  ),
                for (var i = 0; i < count; i++)
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: lefts[i],
                    width: widths[i],
                    top: _pad,
                    height: FloatingPillNav.height - 2 * _pad,
                    child: _NavSlot(
                      data: widget.items[i],
                      selected: i == active,
                      duration: duration,
                      onTap: () => _select(i),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    Widget nav = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: [
              Expanded(child: pill),
              if (widget.trailingAction != null) ...[
                const SizedBox(width: 12),
                widget.trailingAction!,
              ],
            ],
          ),
        ),
      ),
    );
    nav = SafeArea(top: false, child: nav);
    return reduce
        ? nav
        : nav
              .animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
              .move(
                begin: const Offset(0, 24),
                end: Offset.zero,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              );
  }
}

final class _NavSlot extends StatefulWidget {
  const _NavSlot({
    required this.data,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final NavItemData data;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  State<_NavSlot> createState() => _NavSlotState();
}

final class _NavSlotState extends State<_NavSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(_NavSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected &&
        !oldWidget.selected &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final instant = widget.duration == Duration.zero;
    return Semantics(
      button: true,
      selected: selected,
      label: '${widget.data.label} tab${selected ? ', selected' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Icon(
                  widget.data.icon,
                  size: selected ? 22 : 26,
                  color: selected
                      ? _FloatingPillNavState._cream
                      : _FloatingPillNavState._inactive,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(widget.data.label),
                    tween: Tween(begin: instant ? 1 : 0, end: 1),
                    duration: instant
                        ? Duration.zero
                        : const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset((1 - t) * -8, 0),
                        child: child,
                      ),
                    ),
                    child: Text(
                      widget.data.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: _FloatingPillNavState._labelStyle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
