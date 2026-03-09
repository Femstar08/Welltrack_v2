// lib/features/bloodwork/presentation/bloodwork_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../domain/bloodwork_entity.dart';
import '../domain/bloodwork_test_types.dart';
import 'bloodwork_provider.dart';

/// Detail screen showing a historical trend chart for a single bloodwork test.
///
/// The FL Chart LineChart follows the same pattern as training_load_chart.dart:
///  - Container with white background + grey border
///  - ExtraLinesData for reference range shading
///  - FlDotData with per-point colour (green = in-range, red = out-of-range)
///  - X axis: dates, Y axis: numeric value with unit
///
/// Below the chart a scrollable table lists every historical reading with its
/// date, value, and status icon.
class BloodworkDetailScreen extends ConsumerWidget {
  const BloodworkDetailScreen({
    super.key,
    required this.profileId,
    required this.testName,
  });

  final String profileId;
  final String testName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bloodworkProvider(profileId));

    // Filter full history to this test, sorted ascending for charting.
    final history = state.results
        .where((r) => r.testName == testName)
        .toList()
      ..sort((a, b) => a.testDate.compareTo(b.testDate));

    // Look up the catalogue definition for reference range / unit.
    final testType = BloodworkTestType.findByName(testName);

    // Derive reference range from the first result that carries one, falling
    // back to the catalogue definition.
    final refLow = testType?.referenceLow ??
        history.firstWhereOrNull((r) => r.referenceRangeLow != null)
            ?.referenceRangeLow;
    final refHigh = testType?.referenceHigh ??
        history.firstWhereOrNull((r) => r.referenceRangeHigh != null)
            ?.referenceRangeHigh;
    final unit = testType?.unit ??
        (history.isNotEmpty ? history.first.unit : '');

    return Scaffold(
      appBar: AppBar(
        title: Text(testName),
        actions: [
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _OutOfRangeChip(history: history),
            ),
        ],
      ),
      body: state.isLoading && state.results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(bloodworkProvider(profileId).notifier)
                    .loadResults();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Range info banner ──────────────────────────────
                    if (refLow != null || refHigh != null)
                      _RangeBanner(
                        low: refLow,
                        high: refHigh,
                        unit: unit,
                        rangeNote: testType?.rangeNote,
                      ),

                    const SizedBox(height: 16),

                    // ── Chart / empty state ────────────────────────────
                    if (history.isEmpty)
                      _EmptyState(testName: testName)
                    else if (history.length == 1)
                      _SingleValueDisplay(
                        entity: history.first,
                        unit: unit,
                        refLow: refLow,
                        refHigh: refHigh,
                      )
                    else
                      _TrendChart(
                        history: history,
                        refLow: refLow,
                        refHigh: refHigh,
                        unit: unit,
                      ),

                    const SizedBox(height: 24),

                    // ── History table ──────────────────────────────────
                    if (history.isNotEmpty) ...[
                      _HistoryTable(history: history, unit: unit),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Out-of-range chip ─────────────────────────────────────────────────────────

class _OutOfRangeChip extends StatelessWidget {
  const _OutOfRangeChip({required this.history});

  final List<BloodworkEntity> history;

  @override
  Widget build(BuildContext context) {
    // Count the most-recent entry per test for OOR status.
    final outCount = history.where((e) => e.isOutOfRange).length;
    if (outCount == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Chip(
      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
      label: Text('$outCount out of range'),
      backgroundColor: theme.colorScheme.errorContainer,
      labelStyle: TextStyle(
        color: theme.colorScheme.onErrorContainer,
        fontSize: 12,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Range banner ──────────────────────────────────────────────────────────────

class _RangeBanner extends StatelessWidget {
  const _RangeBanner({
    required this.low,
    required this.high,
    required this.unit,
    this.rangeNote,
  });

  final double? low;
  final double? high;
  final String unit;
  final String? rangeNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeText = rangeNote ?? _buildRangeText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF22C55E).withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Color(0xFF22C55E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Normal range: $rangeText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildRangeText() {
    if (low != null && high != null) {
      return '${_fmtVal(low!)} – ${_fmtVal(high!)} $unit';
    }
    if (low != null) return '> ${_fmtVal(low!)} $unit';
    if (high != null) return '< ${_fmtVal(high!)} $unit';
    return unit;
  }

  String _fmtVal(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.testName});

  final String testName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              'No results yet for $testName',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single value display ─────────────────────────────────────────────────────

class _SingleValueDisplay extends StatelessWidget {
  const _SingleValueDisplay({
    required this.entity,
    required this.unit,
    this.refLow,
    this.refHigh,
  });

  final BloodworkEntity entity;
  final String unit;
  final double? refLow;
  final double? refHigh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color statusColor;
    if (entity.isOutOfRange) {
      statusColor = theme.colorScheme.error;
    } else if (entity.isBorderline) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFF22C55E);
    }

    final fmtVal = entity.valueNum
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'\.?0+$'), '');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmtVal,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 16,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(entity.testDate),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add more results to see trends',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ─── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatefulWidget {
  const _TrendChart({
    required this.history,
    required this.unit,
    this.refLow,
    this.refHigh,
  });

  final List<BloodworkEntity> history;
  final double? refLow;
  final double? refHigh;
  final String unit;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.history.map((e) => e.valueNum).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    // Expand Y axis to include reference range if it exists, plus 15 % padding.
    double yMin = minValue;
    double yMax = maxValue;
    if (widget.refLow != null) yMin = yMin < widget.refLow! ? yMin : widget.refLow!;
    if (widget.refHigh != null) yMax = yMax > widget.refHigh! ? yMax : widget.refHigh!;

    final ySpan = (yMax - yMin).abs();
    final padding = ySpan == 0 ? 1.0 : ySpan * 0.15;
    final chartMinY = yMin - padding;
    final chartMaxY = yMax + padding;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — most recent value
          _buildChartHeader(widget.history.last),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              _buildLineChartData(chartMinY, chartMaxY),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildChartHeader(BloodworkEntity latest) {
    final theme = Theme.of(context);
    final Color statusColor;
    if (latest.isOutOfRange) {
      statusColor = theme.colorScheme.error;
    } else if (latest.isBorderline) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFF22C55E);
    }
    final fmtVal = latest.valueNum
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'\.?0+$'), '');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          fmtVal,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          widget.unit,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
        const Spacer(),
        Text(
          'Latest',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(const Color(0xFF22C55E)),
        const SizedBox(width: 4),
        const Text('In range', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 16),
        _legendDot(Colors.red),
        const SizedBox(width: 4),
        const Text('Out of range', style: TextStyle(fontSize: 11, color: Colors.grey)),
        if (widget.refLow != null || widget.refHigh != null) ...[
          const SizedBox(width: 16),
          Container(
            width: 16,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withAlpha(38),
              border: Border.all(
                color: const Color(0xFF22C55E).withAlpha(80),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text('Normal range', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  LineChartData _buildLineChartData(double chartMinY, double chartMaxY) {
    final spots = widget.history.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.valueNum);
    }).toList();

    return LineChartData(
      minY: chartMinY,
      maxY: chartMaxY,
      clipData: const FlClipData.all(),

      // ── Reference range shading as a between-lines band ─────────────
      betweenBarsData: _buildRangeBand(spots, chartMinY, chartMaxY),

      // ── Touch tooltip ───────────────────────────────────────────────
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (event, response) {
          setState(() {
            if (response == null || response.lineBarSpots == null) {
              _touchedIndex = null;
            } else {
              _touchedIndex =
                  response.lineBarSpots!.first.spotIndex;
            }
          });
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final entity = widget.history[spot.spotIndex];
              final fmtVal = entity.valueNum
                  .toStringAsFixed(2)
                  .replaceAll(RegExp(r'\.?0+$'), '');
              return LineTooltipItem(
                '${_labelDate(entity.testDate)}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '$fmtVal ${widget.unit}',
                    style: TextStyle(
                      color: entity.isOutOfRange
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                      fontSize: 12,
                    ),
                  ),
                  if (entity.isOutOfRange)
                    const TextSpan(
                      text: '\nOut of range',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            }).toList();
          },
        ),
      ),

      // ── Grid ────────────────────────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Colors.grey.shade200,
          strokeWidth: 1,
        ),
      ),

      // ── Border ──────────────────────────────────────────────────────
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),

      // ── Axis titles ──────────────────────────────────────────────────
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: _xInterval(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= widget.history.length) {
                return const SizedBox.shrink();
              }
              // Show label only for first, last, and evenly spaced points
              // to avoid crowding on small screens.
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _labelDate(widget.history[index].testDate),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),

      // ── Line bars ───────────────────────────────────────────────────
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: Colors.blue.shade400,
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              final entity = widget.history[index];
              final dotColor =
                  entity.isOutOfRange ? Colors.red : const Color(0xFF22C55E);
              final radius = _touchedIndex == index ? 7.0 : 5.0;
              return FlDotCirclePainter(
                radius: radius,
                color: dotColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }

  /// Builds a band shading the reference range.  Uses two transparent spots
  /// spanning the full x range and a BetweenBarsData to fill the region.
  List<BetweenBarsData> _buildRangeBand(
    List<FlSpot> mainSpots,
    double chartMinY,
    double chartMaxY,
  ) {
    final low = widget.refLow;
    final high = widget.refHigh;
    if (low == null && high == null) return [];

    // Clamp band to chart Y limits.
    final bandLow = (low ?? chartMinY).clamp(chartMinY, chartMaxY);
    final bandHigh = (high ?? chartMaxY).clamp(chartMinY, chartMaxY);

    if (bandLow >= bandHigh) return [];

    // We add two extra invisible line bars that delineate the band and then
    // shade between them.  Index 1 = lower bound, Index 2 = upper bound.
    return [
      BetweenBarsData(
        fromIndex: 1,
        toIndex: 2,
        color: const Color(0xFF22C55E).withAlpha(38),
      ),
    ];
  }

  double _xInterval() {
    final count = widget.history.length;
    if (count <= 4) return 1;
    if (count <= 8) return 2;
    return (count / 4).ceilToDouble();
  }

  String _labelDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year.toString().substring(2)}';
  }
}

// ─── History table ─────────────────────────────────────────────────────────────

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.history,
    required this.unit,
  });

  final List<BloodworkEntity> history;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show most-recent first in the table.
    final sorted = [...history]..sort(
        (a, b) => b.testDate.compareTo(a.testDate),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Results',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Header row
        const _TableRow(
          date: 'Date',
          value: 'Value',
          status: 'Status',
          isHeader: true,
        ),
        const Divider(height: 1),
        ...sorted.map(
          (entity) => Column(
            children: [
              _TableRow.fromEntity(entity: entity, unit: unit),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.date,
    required this.value,
    required this.status,
    this.statusColor,
    this.statusIcon,
    this.isHeader = false,
    this.notes,
  });

  factory _TableRow.fromEntity({
    required BloodworkEntity entity,
    required String unit,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (entity.isOutOfRange) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Out of range';
    } else if (entity.isBorderline) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.info_outline;
      statusLabel = 'Borderline';
    } else {
      statusColor = const Color(0xFF22C55E);
      statusIcon = Icons.check_circle_outline;
      statusLabel = 'Normal';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${entity.testDate.day} ${months[entity.testDate.month - 1]} ${entity.testDate.year}';
    final fmtVal = entity.valueNum
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'\.?0+$'), '');

    return _TableRow(
      date: dateStr,
      value: '$fmtVal $unit',
      status: statusLabel,
      statusColor: statusColor,
      statusIcon: statusIcon,
      notes: entity.notes,
    );
  }

  final String date;
  final String value;
  final String status;
  final Color? statusColor;
  final IconData? statusIcon;
  final bool isHeader;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = isHeader
        ? theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(130),
            letterSpacing: 0.5,
          )
        : theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 110,
            child: Text(date, style: textStyle),
          ),
          // Value
          Expanded(
            child: Text(
              value,
              style: isHeader
                  ? textStyle
                  : textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Status
          if (isHeader)
            Text(status, style: textStyle)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusIcon != null)
                  Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Extension ─────────────────────────────────────────────────────────────────

extension _IterableFirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
