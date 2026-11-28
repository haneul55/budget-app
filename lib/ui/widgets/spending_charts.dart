import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../util/format.dart';

/// 그래프 축에 쓰는 짧은 금액 표기 (예: 15000 → 1.5만).
String compactWon(num v) {
  if (v >= 10000) {
    final man = v / 10000;
    return '${man >= 10 ? man.round() : (man * 10).round() / 10}만'.replaceAll(
      '.0만',
      '만',
    );
  }
  if (v >= 1000) return '${(v / 1000).round()}천';
  return v.round().toString();
}

/// 축 최댓값을 보기 좋게 올림하고, 눈금 4칸 간격을 함께 돌려준다.
({double max, double interval}) _niceAxis(int maxValue) {
  if (maxValue <= 0) return (max: 10000, interval: 2500);
  final raw = maxValue / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [
    1,
    2,
    2.5,
    5,
    10,
  ].map((m) => m * mag).firstWhere((s) => s >= raw);
  return (max: step * 4, interval: step);
}

/// 한 달의 날짜별 쓴 돈 꺾은선 그래프. [cumulative]면 그날까지의 누적.
class DailyLineChart extends StatelessWidget {
  const DailyLineChart({
    super.key,
    required this.month,
    required this.dailyTotals,
    this.cumulative = false,
    this.color,
  });

  final DateTime month;
  final List<int> dailyTotals;
  final bool cumulative;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = color ?? theme.colorScheme.primary;
    final now = DateTime.now();
    final isThisMonth = now.year == month.year && now.month == month.month;
    // 이번 달은 오늘까지만 그린다 (미래 날짜가 0으로 깔리지 않게)
    final lastDay = isThisMonth ? now.day : dailyTotals.length;

    final values = <int>[];
    var running = 0;
    for (var i = 0; i < lastDay; i++) {
      running += dailyTotals[i];
      values.add(cumulative ? running : dailyTotals[i]);
    }
    final axis = _niceAxis(values.fold(0, math.max));
    final gridColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: dailyTotals.length.toDouble(),
        minY: 0,
        maxY: axis.max,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: axis.interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: axis.interval,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(compactWon(v), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final day = v.round();
                final show = day == 1 || day % 5 == 0;
                if (!show || v != day) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text('$day일', style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${month.month}월 ${s.x.round()}일\n${formatWon(s.y.round())}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i + 1.0, values[i].toDouble()),
            ],
            isCurved: cumulative,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: !cumulative,
              checkToShowDot: (spot, _) => spot.y > 0,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 3,
                color: lineColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 월별 합계 막대 그래프. [selected] 달은 진하게 표시하고, 막대를 누르면 [onTapMonth].
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.months,
    this.selected,
    this.onTapMonth,
  });

  final List<({DateTime month, int total})> months;
  final DateTime? selected;
  final ValueChanged<DateTime>? onTapMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axis = _niceAxis(months.fold(0, (m, e) => math.max(m, e.total)));
    final gridColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    bool isSelected(DateTime m) =>
        selected != null &&
        m.year == selected!.year &&
        m.month == selected!.month;

    return BarChart(
      BarChartData(
        maxY: axis.max,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: axis.interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: axis.interval,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(compactWon(v), style: labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final m = months[v.toInt()].month;
                return SideTitleWidget(
                  meta: meta,
                  child: Text('${m.month}월', style: labelStyle),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            final i = response?.spot?.touchedBarGroupIndex;
            if (event is FlTapUpEvent && i != null && onTapMonth != null) {
              onTapMonth!(months[i].month);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${formatMonth(months[group.x].month)}\n${formatWon(rod.toY.round())}',
              TextStyle(
                color: theme.colorScheme.onInverseSurface,
                fontSize: 12,
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].total.toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: isSelected(months[i].month)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.35),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
