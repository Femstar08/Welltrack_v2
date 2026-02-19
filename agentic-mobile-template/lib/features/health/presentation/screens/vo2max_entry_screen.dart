import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Vo2maxEntryScreen extends ConsumerStatefulWidget {
  const Vo2maxEntryScreen({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<Vo2maxEntryScreen> createState() => _Vo2maxEntryScreenState();
}

class _Vo2maxEntryScreenState extends ConsumerState<Vo2maxEntryScreen> {
  final _textController = TextEditingController(text: '40');
  double _sliderValue = 40.0;
  bool _isSaving = false;
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('wt_health_metrics')
          .select()
          .eq('user_id', userId)
          .eq('profile_id', widget.profileId)
          .eq('metric_type', 'vo2max')
          .eq('source', 'manual')
          .order('start_time', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value.roundToDouble();
      _textController.text = _sliderValue.toStringAsFixed(1);
    });
  }

  void _onTextChanged(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null && parsed >= 10 && parsed <= 90) {
      setState(() => _sliderValue = parsed);
    }
  }

  Future<void> _save() async {
    final value = double.tryParse(_textController.text);
    if (value == null || value < 10 || value > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a value between 10 and 90')),
      );
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final dedupeHash = md5
          .convert(utf8.encode(
              '$userId-${widget.profileId}-manual-vo2max-${now.toIso8601String()}'))
          .toString();
      await Supabase.instance.client.from('wt_health_metrics').upsert({
        'user_id': userId,
        'profile_id': widget.profileId,
        'source': 'manual',
        'metric_type': 'vo2max',
        'value_num': value,
        'unit': 'mL/kg/min',
        'start_time': now.toIso8601String(),
        'recorded_at': now.toIso8601String(),
        'dedupe_hash': dedupeHash,
      }, onConflict: 'dedupe_hash');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('VO\u2082 Max saved: ${value.toStringAsFixed(1)} mL/kg/min'),
          backgroundColor: Colors.green[700],
        ));
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _getVo2Color(double v) {
    if (v >= 50) return Colors.green[700]!;
    if (v >= 40) return Colors.blue[700]!;
    if (v >= 30) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  String _getVo2Label(double v) {
    if (v >= 50) return 'Excellent';
    if (v >= 40) return 'Good';
    if (v >= 30) return 'Fair';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('VO\u2082 Max Entry'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Enter your VO\u2082 Max from your Garmin or fitness watch. '
                  'Update every 1\u20132 weeks for accurate tracking.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Column(children: [
            Text(
              _sliderValue.toStringAsFixed(1),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getVo2Color(_sliderValue),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'mL/kg/min  \u2022  ${_getVo2Label(_sliderValue)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _getVo2Color(_sliderValue),
              ),
            ),
          ])),
          const SizedBox(height: 24),
          Slider(
            value: _sliderValue.clamp(10, 90),
            min: 10, max: 90, divisions: 160,
            label: _sliderValue.toStringAsFixed(1),
            onChanged: _onSliderChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10', style: theme.textTheme.bodySmall),
                Text('90', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Precise value',
              suffixText: 'mL/kg/min',
              border: OutlineInputBorder(),
              helperText: 'Range: 10\u201390',
            ),
            onChanged: _onTextChanged,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Entry'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 32),
          Text('History', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Icon(Icons.timeline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No entries yet', style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  )),
                ]),
              ),
            )
          else
            ..._history.map((entry) => _buildHistoryTile(entry)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> entry) {
    final value = (entry['value_num'] as num?)?.toDouble() ?? 0;
    final date = entry['start_time'] as String? ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getVo2Color(value).withValues(alpha: 0.15),
          child: Text(value.toStringAsFixed(0), style: TextStyle(
            color: _getVo2Color(value), fontWeight: FontWeight.bold, fontSize: 14,
          )),
        ),
        title: Text('${value.toStringAsFixed(1)} mL/kg/min',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_formatDate(date)),
        trailing: Text(_getVo2Label(value), style: TextStyle(
          color: _getVo2Color(value), fontWeight: FontWeight.w500, fontSize: 12,
        )),
      ),
    );
  }
}
