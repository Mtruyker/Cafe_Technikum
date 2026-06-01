import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'order_status_badge.dart';

class StaffReportCharts extends StatelessWidget {
  const StaffReportCharts({super.key, required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final dailyPoints = _dailyPoints(report);
    final statusEntries = report.byStatus.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));

    return Column(
      children: [
        _ChartCard(
          title: 'Выручка по дням',
          subtitle: 'Динамика только по неотмененным заказам.',
          child: _RevenueChart(points: dailyPoints),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChartCard(
          title: 'Заказы по дням',
          subtitle: 'Количество оформленных заказов в выбранном периоде.',
          child: _OrdersChart(points: dailyPoints),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChartCard(
          title: 'Статусы заказов',
          subtitle: 'Распределение по текущим статусам.',
          child: _StatusPieChart(entries: statusEntries),
        ),
      ],
    );
  }

  static List<_DailyChartPoint> _dailyPoints(SalesReport report) {
    final keys = {
      ...report.ordersByDay.keys,
      ...report.revenueByDay.keys,
    }.toList(growable: false)..sort();

    return keys
        .map(
          (day) => _DailyChartPoint(
            day: day,
            orders: report.ordersByDay[day] ?? 0,
            revenue: report.revenueByDay[day] ?? 0,
          ),
        )
        .toList(growable: false);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});

  final List<_DailyChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _NoChartData(label: 'Нет данных по выручке.');
    }

    final maxRevenue = points.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.revenue),
    );
    final chartWidth = math.max(
      MediaQuery.of(context).size.width - 80,
      points.length * 56.0,
    );

    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              maxY: maxRevenue <= 0 ? 1 : maxRevenue * 1.2,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxRevenue <= 0 ? 1 : maxRevenue / 4,
              ),
              borderData: FlBorderData(show: false),
              alignment: BarChartAlignment.spaceAround,
              titlesData: _buildBottomTitles(
                context,
                points,
                leftValueFormatter: (value) => value >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}k'
                    : value.toStringAsFixed(0),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x.toInt()];
                    return BarTooltipItem(
                      '${_dayLabel(point.day)}\n${formatRub(point.revenue)}',
                      Theme.of(context).textTheme.bodySmall!,
                    );
                  },
                ),
              ),
              barGroups: List.generate(
                points.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: points[index].revenue,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersChart extends StatelessWidget {
  const _OrdersChart({required this.points});

  final List<_DailyChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _NoChartData(label: 'Нет данных по количеству заказов.');
    }

    final maxOrders = points.fold<int>(
      0,
      (maxValue, point) => math.max(maxValue, point.orders),
    );
    final chartWidth = math.max(
      MediaQuery.of(context).size.width - 80,
      points.length * 56.0,
    );

    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxOrders <= 0 ? 1 : maxOrders * 1.4,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxOrders <= 0
                    ? 1
                    : math.max(1, maxOrders / 4),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _buildBottomTitles(
                context,
                points,
                leftValueFormatter: (value) => value.toStringAsFixed(0),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((spot) {
                        final point = points[spot.x.toInt()];
                        return LineTooltipItem(
                          '${_dayLabel(point.day)}\n${point.orders} заказов',
                          Theme.of(context).textTheme.bodySmall!,
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: Theme.of(context).colorScheme.secondary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.12),
                  ),
                  spots: List.generate(
                    points.length,
                    (index) => FlSpot(
                      index.toDouble(),
                      points[index].orders.toDouble(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _NoChartData(label: 'Нет данных по статусам.');
    }

    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: entries
                    .map(
                      (entry) => PieChartSectionData(
                        color: orderStatusColor(
                          context,
                          orderStatusFromValue(entry.key),
                        ),
                        value: entry.value.toDouble(),
                        title: entry.value.toString(),
                        radius: 74,
                        titleStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries
                  .map((entry) {
                    final status = orderStatusFromValue(entry.key);
                    final share = total == 0 ? 0 : (entry.value / total) * 100;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OrderStatusBadge(status: status),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${entry.value} шт. • ${share.toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

FlTitlesData _buildBottomTitles(
  BuildContext context,
  List<_DailyChartPoint> points, {
  required String Function(double value) leftValueFormatter,
}) {
  final showEvery = points.length <= 6 ? 1 : (points.length / 6).ceil();

  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 42,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xxs),
          child: Text(
            leftValueFormatter(value),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= points.length) {
            return const SizedBox.shrink();
          }
          if (index % showEvery != 0 && index != points.length - 1) {
            return const SizedBox.shrink();
          }

          return SideTitleWidget(
            meta: meta,
            child: Text(
              _dayLabel(points[index].day),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          );
        },
      ),
    ),
  );
}

String _dayLabel(DateTime day) {
  final d = day.day.toString().padLeft(2, '0');
  final m = day.month.toString().padLeft(2, '0');
  return '$d.$m';
}

class _DailyChartPoint {
  const _DailyChartPoint({
    required this.day,
    required this.orders,
    required this.revenue,
  });

  final DateTime day;
  final int orders;
  final double revenue;
}

class _NoChartData extends StatelessWidget {
  const _NoChartData({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
