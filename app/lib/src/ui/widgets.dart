import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../domain/format.dart';
import '../domain/models.dart';
import '../domain/summary.dart';
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

/// A screen's title row: the title, then the screen's own actions on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(child: Heading(title, style: Styles.screenTitle)),
          ...actions,
        ],
      ),
    );
  }
}

/// A section's heading, with an optional figure on the right ("Today · RM 24.60 spent").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Side by side when they fit; with large text the figure wraps under the title.
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: MergeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Space.l,
            children: [
              Heading(title),
              if (trailing != null) Text(trailing!, style: Styles.meta.copyWith(fontSize: 14, fontFeatures: tabular)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows on one surface, separated by hairlines: a list that reads as one thing.
class ListSurface extends StatelessWidget {
  const ListSurface({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Material(
        color: Palette.card,
        shape: const RoundedRectangleBorder(
          borderRadius: corners,
          side: BorderSide(color: Palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: Space.l, endIndent: Space.l),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The icon for a category, so lists can be scanned by shape before reading.
IconData categoryIcon(String category) => switch (category) {
  'Food & Drinks' => Icons.restaurant,
  'Groceries' => Icons.shopping_basket_outlined,
  'Transport' => Icons.directions_transit_outlined,
  'Shopping' => Icons.shopping_bag_outlined,
  'Bills' => Icons.receipt_outlined,
  'AI & software' => Icons.memory_outlined,
  'Entertainment' => Icons.movie_outlined,
  'Transfers' => Icons.swap_horiz,
  'Currency exchange' => Icons.currency_exchange,
  'Money in' => Icons.south_west,
  _ => Icons.more_horiz,
};

/// A category's icon on a small square.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key});

  final String category;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: Palette.tile, borderRadius: corners),
      child: Icon(categoryIcon(category), size: 20, color: Palette.text2),
    ),
  );
}

/// A list row: an optional category icon, the name and one fact under it on the left,
/// the amount and one fact under it on the right. With large text the right side
/// moves under the name, so neither is squeezed.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.name,
    required this.under,
    required this.amount,
    required this.amountColor,
    required this.aside,
    this.onTap,
  });

  final String? icon;
  final String name;
  final String? under;
  final String amount;
  final Color? amountColor;
  final String? aside;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stacked = context.largeText;
    final amountText = Text(amount, style: Styles.rowAmount.copyWith(color: amountColor));
    Widget meta(String text) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: Styles.meta),
    );
    final row = Row(
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[CategoryIcon(icon!), const SizedBox(width: Space.m)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Styles.rowName),
              if (stacked) amountText,
              if (under != null) meta(under!),
              if (stacked && aside != null) meta(aside!),
            ],
          ),
        ),
        if (!stacked) ...[
          const SizedBox(width: Space.m),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [amountText, if (aside != null) meta(aside!)]),
        ],
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      child: row,
    );
    return MergeSemantics(
      child: onTap == null ? padded : InkWell(onTap: onTap, child: padded),
    );
  }
}

/// A transaction: its category's icon, the place and the category, the amount and the
/// time. In a category's own list the icon and category would repeat, so the day
/// and time take their place.
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, required this.now, this.inCategory = false, this.onTap});

  final Txn txn;
  final DateTime now;
  final bool inCategory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final moneyIn = !txn.isSpending;
    return _ListRow(
      icon: inCategory ? null : txn.category,
      name: displayName(txn.name),
      under: inCategory ? whenLabel(txn.date, now: now) : txn.category,
      amount: '${moneyIn ? '+' : ''}${rm(txn.cents.abs())}',
      amountColor: moneyIn ? Palette.good : null,
      aside: inCategory ? null : time12(txn.date),
      onTap: onTap,
    );
  }
}

/// A big amount with the lines that explain it, for the top of a screen.
class Headline extends StatelessWidget {
  const Headline({super.key, required this.cents, required this.lines, this.color, this.size});

  final int? cents;
  final List<String> lines;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final big = size ?? context.heroSize;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      container: true,
      label: [if (cents == null) 'Unknown' else rm(cents!), ...lines].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: scaler.scale(big) * 1.15,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(cents, size: big, color: color, textScaler: scaler),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(lines.first, style: Styles.desc.copyWith(fontSize: 16)),
          for (final line in lines.skip(1)) ...[const SizedBox(height: Space.xs), Text(line, style: Styles.extra)],
        ],
      ),
    );
  }
}

/// A place's total: its name (and category, where the list mixes them), then the
/// amount and how often.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place, this.showCategory = true});

  final PlaceTotal place;
  final bool showCategory;

  @override
  Widget build(BuildContext context) => _ListRow(
    icon: showCategory ? place.category : null,
    name: displayName(place.name),
    under: showCategory ? place.category : null,
    amount: rm(place.cents),
    amountColor: null,
    aside: plural(place.count, 'time'),
  );
}

/// One transaction in full: everything Wise sent that the row leaves out.
Future<void> showTxnDetails(BuildContext context, Txn txn, DateTime now) {
  final moneyIn = !txn.isSpending;
  final note = txn.note;
  // Card notes ("Card transaction of 12.50 MYR issued by …") only repeat what's shown.
  final usefulNote =
      note.isNotEmpty &&
      note.toLowerCase() != txn.name.toLowerCase() &&
      !note.toLowerCase().startsWith('card transaction of ');
  final shownName = displayName(txn.name);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(txn.category),
                const SizedBox(width: Space.m),
                Expanded(child: Heading(shownName, style: Styles.title)),
              ],
            ),
            const SizedBox(height: Space.l),
            Semantics(
              label: '${moneyIn ? 'Received' : 'Spent'} ${rm(txn.cents.abs())}',
              excludeSemantics: true,
              child: MoneyText(txn.cents.abs(), size: 32, color: moneyIn ? Palette.good : null),
            ),
            const SizedBox(height: Space.l),
            _Detail('When', whenLabel(txn.date, now: now)),
            _Detail('Category', txn.category),
            if (shownName != txn.name) _Detail('Name from Wise', txn.name),
            if (usefulNote) _Detail('Note', note),
          ],
        ),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Styles.meta),
            const SizedBox(height: 2),
            Text(value, style: Styles.rowName),
          ],
        ),
      ),
    );
  }
}
