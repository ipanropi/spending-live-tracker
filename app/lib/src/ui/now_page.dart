import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../domain/format.dart';
import '../domain/pace.dart';
import 'status.dart';
import 'theme.dart';
import 'widgets.dart';

/// Two columns from here: the money and its pace on the left, today on the right.
const double _twoColumnsFrom = 760;

/// "Am I OK until payday?" What's left, whether it will last, and what today cost.
class NowPage extends StatelessWidget {
  const NowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final period = c.period;
    return TabScroll(
      slivers: [
        const SliverToBoxAdapter(child: ScreenHeader('Now', actions: [RefreshButton(), SettingsButton()])),
        const SliverToBoxAdapter(child: UpdatedLabel()),
        const SliverToBoxAdapter(child: ErrorBanner()),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
        SliverToBoxAdapter(
          child: period != null
              ? _NowBody(period: period, c: c)
              : (c.error == null ? const _NowSkeleton() : const SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _NowBody extends StatelessWidget {
  const _NowBody({required this.period, required this.c});

  final PayPeriod period;
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final money = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Headline(
          cents: period.balanceCents,
          color: stateColor(period.state),
          lines: ['left until payday, ${weekdayDayMonth(period.end)}', '${plural(period.daysLeft, 'day')} to go'],
        ),
        if (period.state != PaceState.unknown) ...[const SizedBox(height: Space.xl), PaceCard(period: period)],
      ],
    );
    final today = _TodaySection(period: period, now: c.now, onAll: () => c.selectTab(AppTab.activity));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnsFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              money,
              const SizedBox(height: Space.xxl),
              today,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: money),
            const SizedBox(width: Space.xxl),
            Expanded(flex: 2, child: today),
          ],
        );
      },
    );
  }
}

/// Green when on pace, amber when spending fast, red only below zero.
Color stateColor(PaceState state) => switch (state) {
  PaceState.onPace => Palette.good,
  PaceState.fast => Palette.warn,
  PaceState.overspent => Palette.spend,
  PaceState.unknown => Palette.text,
};

/// The verdict in words, then the burn-down that backs it up.
class PaceCard extends StatelessWidget {
  const PaceCard({super.key, required this.period});

  final PayPeriod period;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(period.state);
    final ahead = period.aheadCents!;
    final (verdict, advice) = switch (period.state) {
      PaceState.onPace => (
        'On pace: ${rmWhole(ahead)} to spare',
        '${rmWhole(period.perDayCents!)} a day lasts until payday.',
      ),
      PaceState.fast => (
        'Spending fast: ${rmWhole(-ahead)} over pace',
        '${rmWhole(period.perDayCents!)} a day from now lasts until payday.',
      ),
      _ => (
        'Overspent by ${rmWhole(-period.balanceCents!)}',
        'The next top-up is on payday, ${weekdayDayMonth(period.end)}.',
      ),
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Heading(verdict, style: Styles.sectionTitle.copyWith(color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(advice, style: Styles.desc.copyWith(fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          PaceChart(period: period, color: color),
          const SizedBox(height: Space.m),
          ExcludeSemantics(
            child: Wrap(
              spacing: Space.l,
              runSpacing: Space.xs,
              children: [
                _LegendItem(label: 'Money left', color: color, dashed: false),
                const _LegendItem(label: 'Even pace to payday', color: Palette.muted, dashed: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color, required this.dashed});

  final String label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 3),
          painter: _LinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: Space.s - 2),
        Flexible(child: Text(label, style: Styles.meta.copyWith(fontSize: 12))),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 2.5;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color || old.dashed != dashed;
}

/// Money left by day since payday, against the even pace that reaches zero on the
/// next payday. Above the dashed line, you're fine.
class PaceChart extends StatelessWidget {
  const PaceChart({super.key, required this.period, required this.color});

  final PayPeriod period;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final labelSize = scaler.scale(wide ? 12 : 11);
    final plot = wide ? 180.0 : 130.0;
    final position = period.state == PaceState.onPace ? 'above' : 'below';
    return Semantics(
      label:
          'Chart of money left this pay period, $position an even pace: '
          '${rm(period.balanceCents!)} left on day ${period.dayNumber} of ${period.days}, '
          'where an even pace would leave ${rm(period.evenPaceLeftCents!)}.',
      excludeSemantics: true,
      child: SizedBox(
        height: plot + labelSize * 1.4 + Space.s,
        child: CustomPaint(
          size: Size.infinite,
          painter: _PacePainter(
            leftByDay: period.leftByDay,
            days: period.days,
            available: period.availableCents!,
            color: color,
            plotHeight: plot,
            labelSize: labelSize,
            startLabel: dayMonth(period.start),
            endLabel: dayMonth(period.end),
          ),
        ),
      ),
    );
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter({
    required this.leftByDay,
    required this.days,
    required this.available,
    required this.color,
    required this.plotHeight,
    required this.labelSize,
    required this.startLabel,
    required this.endLabel,
  });

  final List<int> leftByDay;
  final int days;
  final int available;
  final Color color;
  final double plotHeight;
  final double labelSize;
  final String startLabel;
  final String endLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0; // room for the today dot at the very top
    final w = size.width;
    final bottom = plotHeight;
    final low = math.min(0, leftByDay.reduce(math.min));
    final high = math.max(available, leftByDay.reduce(math.max));
    final span = math.max(1, high - low);
    double x(num day) => w * day / days;
    double y(num cents) => top + (bottom - top) * (high - cents) / span;

    // Zero line, and the even pace from what you had at payday to nothing on the next one.
    canvas.drawLine(Offset(0, y(0)), Offset(w, y(0)), Paint()..color = Palette.line);
    final dash = Paint()
      ..color = Palette.muted
      ..strokeWidth = 1.5;
    final from = Offset(x(0), y(available));
    final to = Offset(x(days), y(0));
    final length = (to - from).distance;
    final step = (to - from) / length;
    for (double d = 0; d < length; d += 9) {
      canvas.drawLine(from + step * d, from + step * math.min(d + 5, length), dash);
    }

    // Today: a faint rule, the line so far, and a dot where you are.
    final today = leftByDay.length - 1;
    canvas.drawLine(Offset(x(today), top / 2), Offset(x(today), y(low)), Paint()..color = const Color(0xFF3A3A36));
    final path = Path()..moveTo(x(0), y(leftByDay[0]));
    for (var k = 1; k < leftByDay.length; k++) {
      path.lineTo(x(k), y(leftByDay[k]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Offset(x(today), y(leftByDay[today]));
    canvas
      ..drawCircle(dot, 6.5, Paint()..color = Palette.card)
      ..drawCircle(dot, 4.5, Paint()..color = color);

    // Labels: payday, today, next payday. Today wins when they would collide.
    final labelTop = bottom + Space.s;
    final todayLabel = _label('Today', Palette.text2);
    final todayLeft = (x(today) - todayLabel.width / 2).clamp(0.0, w - todayLabel.width);
    final start = _label(startLabel, Palette.muted);
    final end = _label(endLabel, Palette.muted);
    const gap = 8;
    if (start.width + gap < todayLeft) start.paint(canvas, Offset(0, labelTop));
    if (todayLeft + todayLabel.width + gap < w - end.width) end.paint(canvas, Offset(w - end.width, labelTop));
    todayLabel.paint(canvas, Offset(todayLeft, labelTop));
  }

  TextPainter _label(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: labelSize, color: color, height: 1.2),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_PacePainter old) =>
      old.leftByDay != leftByDay ||
      old.color != color ||
      old.plotHeight != plotHeight ||
      old.labelSize != labelSize ||
      old.available != available;
}

/// Today's payments, newest first, and the way to everything else.
class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.period, required this.now, required this.onAll});

  final PayPeriod period;
  final DateTime now;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Today', trailing: period.todayCents > 0 ? '${rm(period.todayCents)} spent' : null),
        ListSurface(
          children: [
            if (period.today.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Space.l),
                child: Text('Nothing spent yet today.', style: Styles.meta),
              ),
            for (final t in period.today) TxnTile(txn: t, now: now, onTap: () => showTxnDetails(context, t, now)),
          ],
        ),
        const SizedBox(height: Space.xs),
        ViewAllButton('All activity', onPressed: onAll),
      ],
    );
  }
}

/// The Now screen's shape while the first update loads.
class _NowSkeleton extends StatelessWidget {
  const _NowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(width: 0.6, height: 48),
          SizedBox(height: Space.m),
          SkeletonBox(width: 0.5, height: 14),
          SizedBox(height: Space.s),
          SkeletonBox(width: 0.25, height: 12),
          SizedBox(height: Space.xl),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBox(width: 0.55, height: 16),
                SizedBox(height: Space.s),
                SkeletonBox(width: 0.45, height: 12),
                SizedBox(height: Space.l),
                SkeletonBox(width: 1, height: 130),
              ],
            ),
          ),
          SizedBox(height: Space.xxl),
          SkeletonBox(width: 0.2, height: 16),
          SizedBox(height: Space.m),
          SkeletonBox(width: 1, height: 64),
          SizedBox(height: Space.xs),
          SkeletonBox(width: 1, height: 64),
        ],
      ),
    );
  }
}
