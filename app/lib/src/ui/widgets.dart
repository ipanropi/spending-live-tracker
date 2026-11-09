import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../domain/format.dart';
import 'theme.dart';

/// Gives widgets below it access to the [AppController].
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// The controller, rebuilding the caller whenever it changes.
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// The controller, without rebuilding the caller. For event handlers.
  static AppController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// A flat panel: dark surface, thin border, 4px corners. One panel holds one group
/// of related things, so there are few of them and each means something.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A Material, so the press ripple of buttons inside shows on the panel, not under it.
    return Semantics(
      container: true,
      child: Material(
        color: Palette.card,
        shape: const RoundedRectangleBorder(
          borderRadius: corners,
          side: BorderSide(color: Palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: EdgeInsets.all(context.pad), child: child),
      ),
    );
  }
}

/// "RM" and the cents are drawn smaller and dimmer than the ringgit, so the eye
/// lands on the value. 81% is the least opacity that keeps the red at 4.5:1.
const double _quietAlpha = 0.81;

/// An amount as a focal number: the ringgit big, "RM" and the cents quieter.
class MoneyText extends StatelessWidget {
  const MoneyText(this.cents, {super.key, required this.size, this.color, this.textScaler});

  /// Null shows a dash, for "unknown".
  final int? cents;
  final double size;
  final Color? color;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Palette.text;
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size > 36 ? -0.5 : 0,
      height: 1.15,
      color: color,
      fontFeatures: tabular,
    );
    if (cents == null) return Text('–', style: style, textScaler: textScaler);
    final (sign, number) = rmParts(cents!);
    final dot = number.lastIndexOf('.');
    final quiet = TextStyle(
      fontWeight: FontWeight.w600,
      color: color.withValues(alpha: _quietAlpha),
    );
    return Text.rich(
      TextSpan(
        children: [
          if (sign.isNotEmpty) TextSpan(text: sign),
          TextSpan(
            text: 'RM ',
            style: quiet.copyWith(fontSize: size * 0.5),
          ),
          TextSpan(text: number.substring(0, dot)),
          TextSpan(
            text: number.substring(dot),
            style: quiet.copyWith(fontSize: size * 0.6),
          ),
        ],
      ),
      style: style,
      maxLines: 1,
      textScaler: textScaler,
    );
  }
}

/// A figure: the number on its own line as the focal point, then one short
/// phrase per line under it. Read by screen readers as one sentence.
class Figure extends StatelessWidget {
  const Figure({super.key, required this.cents, required this.lines, this.color, this.hero = false});

  final int? cents;
  final List<String> lines;
  final Color? color;

  /// The one number that matters most on the screen.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final size = hero ? context.heroSize : context.statSize;
    // The numbers are already large; past 1.3× they'd only be shrunk back to fit.
    // All the other text scales fully with the system setting.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      container: true,
      // "RM 1,780.00, left until 22 Nov, 14 days left"
      label: [if (cents == null) 'Unknown' else rm(cents!), ...lines].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A fixed-height line for the number: long amounts shrink just enough to fit.
          SizedBox(
            height: scaler.scale(size) * 1.15,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(cents, size: size, color: color, textScaler: scaler),
            ),
          ),
          SizedBox(height: hero ? Space.m : Space.s),
          Text(lines.first, style: hero ? Styles.desc.copyWith(fontSize: 16) : Styles.desc),
          for (final line in lines.skip(1)) ...[const SizedBox(height: Space.xs), Text(line, style: Styles.extra)],
        ],
      ),
    );
  }
}

/// A list row: the name with the amount on the right, then one piece of
/// information per line under it.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.name,
    required this.amount,
    this.amountColor,
    this.lines = const [],
    this.below,
    this.trailing,
  });

  final String name;
  final String amount;
  final Color? amountColor;
  final List<String> lines;

  /// Shown right under the first line, before [lines]. Used for the share bar.
  final Widget? below;

  /// After the amount, e.g. a dropdown arrow.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(displayName(name), style: Styles.rowName)),
              const SizedBox(width: Space.l),
              Text(amount, style: Styles.rowAmount.copyWith(color: amountColor)),
              if (trailing != null) ...[const SizedBox(width: Space.m), trailing!],
            ],
          ),
          ?below,
          for (final line in lines) ...[const SizedBox(height: Space.xs), Text(line, style: Styles.meta)],
        ],
      ),
    );
  }
}

/// Rows separated by dividers, each with the same breathing room.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows, this.vertical = Space.l});

  final List<Widget> rows;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: vertical),
            child: rows[i],
          ),
        ],
      ],
    );
  }
}

/// A thin bar showing a share of the month's spending, with the percentage beside it.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: Container(
                height: 6,
                color: Palette.line,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0, 1),
                  child: const ColoredBox(color: Palette.bar, child: SizedBox.expand()),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.m),
          // A minimum width keeps bars aligned; it can still grow with large text.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Text(
              '${(fraction * 100).round()}%',
              textAlign: TextAlign.right,
              style: Styles.meta.copyWith(fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}

/// A panel or list heading, marked as a heading for screen readers.
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.style = Styles.sectionTitle});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(header: true, child: Text(text, style: style));
}

/// A right-pointing chevron: "goes to another page". Dropdowns use ⌄ instead.
class Chevron extends StatelessWidget {
  const Chevron({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(Icons.chevron_right, color: Palette.muted, size: size),
  );
}

/// A labelled way into a full list. The label names where it goes ("View all
/// categories"), so it doesn't depend on spotting an icon, and the whole row is
/// a 48dp target.
class ViewAllButton extends StatelessWidget {
  const ViewAllButton(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        minimumSize: const Size.fromHeight(48),
        textStyle: Styles.rowName.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const Chevron(size: 20),
        ],
      ),
    );
  }
}

/// A two-or-more-way switch, like Categories | Places: labelled options with the
/// chosen one filled. Exactly 48dp tall on every platform, so it's an easy target
/// and measures true when panels share a height (Flutter's SegmentedButton is
/// shorter on desktop and under-reports its height).
class ChoiceSwitch<T> extends StatelessWidget {
  const ChoiceSwitch({super.key, required this.options, required this.selected, required this.onChanged});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Clipped to the 4px corners, with the outline drawn over the chosen side's fill.
    return ClipRRect(
      borderRadius: corners,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: corners,
          border: Border.all(color: Palette.line),
        ),
        child: _row(),
      ),
    );
  }

  Widget _row() {
    return Row(
      children: [
        for (final (value, label) in options)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == selected,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: value == selected ? Palette.line : Colors.transparent,
                child: InkWell(
                  onTap: value == selected ? null : () => onChanged(value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: value == selected ? Palette.text : Palette.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// An error notice: what happened, why, and what you're seeing meanwhile, one per line,
/// with the way to fix it as a button.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.title, required this.lines, this.action, this.onAction});

  final String title;
  final List<String> lines;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(color: Palette.errorText, fontSize: 14, height: 1.4);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
        decoration: BoxDecoration(
          color: Palette.errorBg,
          borderRadius: corners,
          border: Border.all(color: Palette.errorLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.error_outline, color: Palette.errorText, size: 20),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.copyWith(fontWeight: FontWeight.w600)),
                  for (final line in lines) ...[
                    const SizedBox(height: Space.xs),
                    Text(line, style: text.copyWith(color: Palette.errorText.withValues(alpha: 0.85))),
                  ],
                ],
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: Palette.errorText),
                child: Text(action!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing placeholder in the shape of what's loading, so the wait feels shorter
/// than a spinner and the layout doesn't jump when data arrives.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  /// Built from [SkeletonBox]es.
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "reduce motion": a still placeholder instead of a pulsing one.
    if (context.reduceMotion) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading your data',
    liveRegion: true,
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    ),
  );
}

/// One grey block inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height});

  /// A fraction of the available width (0–1).
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: width,
    child: Container(
      height: height,
      decoration: const BoxDecoration(color: Palette.line, borderRadius: corners),
    ),
  );
}

/// The app's mark: a white doughnut chart on blue, drawn instead of shipped as an image.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.12)),
      Paint()..color = Palette.accent,
    );
    final stroke = s * 0.14;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: s * 0.24);
    const gap = 0.1; // radians between segments
    final segments = [
      (0.0, 205.0, Colors.white),
      (205.0, 290.0, const Color(0xFFBFDBFE)),
      (290.0, 360.0, const Color(0xFF93C5FD)),
    ];
    for (final (from, to, color) in segments) {
      final start = (from - 90) * math.pi / 180 + gap / 2;
      final sweep = (to - from) * math.pi / 180 - gap;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
