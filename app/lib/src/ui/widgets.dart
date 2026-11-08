import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'theme.dart';

/// Gives widgets below it access to the [AppController].
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// The controller, rebuilding the caller whenever it changes.
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// The controller, without rebuilding the caller. For event handlers.
  static AppController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// A flat card: dark surface, thin border, 4px corners. Tappable when [onTap] is set.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: EdgeInsets.all(context.pad), child: child);
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Palette.card,
        shape: const RoundedRectangleBorder(
          borderRadius: corners,
          side: BorderSide(color: Palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// An overview card: the number on its own line as the focal point, then one
/// short phrase per line under it.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.lines, this.color, this.hero = false});

  final String value;
  final List<String> lines;
  final Color? color;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Semantics(
        label: [value, ...lines].join(', '),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Long amounts shrink just enough to fit instead of overflowing.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: hero ? context.heroSize : context.statSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: hero ? -0.5 : 0,
                  height: 1.15,
                  color: color ?? Palette.text,
                  fontFeatures: tabular,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(lines.first, style: hero ? Styles.desc.copyWith(fontSize: 16) : Styles.desc),
            for (final line in lines.skip(1)) ...[const SizedBox(height: 3), Text(line, style: Styles.extra)],
          ],
        ),
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

  /// After the amount, e.g. a dropdown chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(name, style: Styles.rowName)),
              const SizedBox(width: 16),
              Text(amount, style: Styles.rowAmount.copyWith(color: amountColor)),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          ?below,
          for (final line in lines) ...[const SizedBox(height: 5), Text(line, style: Styles.meta)],
        ],
      ),
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
      padding: const EdgeInsets.only(top: 10),
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
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
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

/// A dashboard card with a title, a preview of a list, and a chevron that opens all of it.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.rows,
    required this.total,
    required this.empty,
    required this.onOpen,
  });

  final String title;

  /// The preview rows (already limited).
  final List<Widget> rows;

  /// How many items there are in all.
  final int total;
  final String empty;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final more = total - rows.length;
    return Panel(
      onTap: onOpen,
      semanticLabel: '$title. Show all',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Styles.sectionTitle)),
              const Icon(Icons.chevron_right, color: Palette.muted, size: 22),
            ],
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(empty, style: Styles.meta),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: i == rows.length - 1 ? 0 : 16),
              child: rows[i],
            ),
          ],
          if (more > 0) ...[const SizedBox(height: 16), Text('+$more more', style: Styles.meta)],
        ],
      ),
    );
  }
}

/// A red notice with an optional action, for errors.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: Palette.errorBg,
          borderRadius: corners,
          border: Border.all(color: Palette.errorLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Palette.errorText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Palette.errorText, fontSize: 14, height: 1.4)),
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
