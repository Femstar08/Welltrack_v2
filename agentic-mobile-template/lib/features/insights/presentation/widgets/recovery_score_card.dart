import 'package:flutter/material.dart';
import '../../domain/recovery_score_entity.dart';

/// Recovery Score Card
/// Large, prominent card displaying recovery score with circular indicator
class RecoveryScoreCard extends StatefulWidget {

  const RecoveryScoreCard({
    super.key,
    required this.score,
    required this.trend,
  });
  final RecoveryScoreEntity score;
  final RecoveryTrend trend;

  @override
  State<RecoveryScoreCard> createState() => _RecoveryScoreCardState();
}

class _RecoveryScoreCardState extends State<RecoveryScoreCard> {
  bool _showBreakdown = false;

  @override
  Widget build(BuildContext context) {
    final colorMap = {
      RecoveryScoreColor.green: Colors.green,
      RecoveryScoreColor.lightGreen: Colors.lightGreen,
      RecoveryScoreColor.yellow: Colors.amber,
      RecoveryScoreColor.orange: Colors.orange,
      RecoveryScoreColor.red: Colors.red,
    };

    final scoreColor = colorMap[widget.score.colorCode]!;

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          setState(() {
            _showBreakdown = !_showBreakdown;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Recovery Score',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildTrendIndicator(),
                ],
              ),
              const SizedBox(height: 24),
              // Circular progress indicator
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: widget.score.recoveryScore / 100,
                        strokeWidth: 16,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.score.recoveryScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          widget.score.interpretationLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.score.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Component breakdown
              if (_showBreakdown) ...[
                const Divider(),
                const SizedBox(height: 12),
                _buildComponentBreakdown(),
              ] else ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showBreakdown = true;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('View Breakdown'),
                ),
              ],
              // Missing components warning
              if (widget.score.missingComponents.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMissingComponentsWarning(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    IconData icon;
    Color color;
    String tooltip;

    switch (widget.trend) {
      case RecoveryTrend.up:
        icon = Icons.trending_up;
        color = Colors.green;
        tooltip = 'Improving';
        break;
      case RecoveryTrend.down:
        icon = Icons.trending_down;
        color = Colors.red;
        tooltip = 'Declining';
        break;
      case RecoveryTrend.flat:
        icon = Icons.trending_flat;
        color = Colors.grey;
        tooltip = 'Stable';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildComponentBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Component Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.score.stressComponent != null)
          _buildComponentRow(
            'Stress',
            widget.score.stressComponent!,
            Icons.psychology,
          ),
        if (widget.score.sleepComponent != null)
          _buildComponentRow(
            'Sleep',
            widget.score.sleepComponent!,
            Icons.nightlight_round,
          ),
        if (widget.score.hrComponent != null)
          _buildComponentRow(
            'Heart Rate',
            widget.score.hrComponent!,
            Icons.favorite,
          ),
        if (widget.score.loadComponent != null)
          _buildComponentRow(
            'Training Load',
            widget.score.loadComponent!,
            Icons.fitness_center,
          ),
      ],
    );
  }

  Widget _buildComponentRow(String label, double value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getColorForValue(value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingComponentsWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Missing: ${widget.score.missingComponents.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.lightGreen;
    if (value >= 40) return Colors.amber;
    if (value >= 20) return Colors.orange;
    return Colors.red;
  }
}
