import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simple weight logging screen.
/// Full persistence implementation in P14-014.
class WeightLogScreen extends StatefulWidget {
  const WeightLogScreen({super.key});

  @override
  State<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Log Weight'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your weight',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a weight';
                  }
                  final num = double.tryParse(value);
                  if (num == null) return 'Enter a valid number';
                  if (num < 20 || num > 500) {
                    return 'Weight must be between 20 and 500 kg';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    // Persistence wired in P14-014
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Logged ${_controller.text} kg'),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
