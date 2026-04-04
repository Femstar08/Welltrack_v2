import 'package:flutter/material.dart';

/// Step 5 (final) of the morning check-in wizard — Injuries & pain.
///
/// Optional free-text field. Two submit paths:
/// - "No injuries" skips text entry and submits immediately
/// - "Submit" submits with whatever text the user typed (may be empty)
class CheckInStepInjuries extends StatefulWidget {
  const CheckInStepInjuries({
    required this.injuriesNotes,
    required this.isSubmitting,
    required this.error,
    required this.onInjuriesChanged,
    required this.onNoInjuries,
    required this.onSubmit,
    super.key,
  });

  final String? injuriesNotes;
  final bool isSubmitting;
  final String? error;
  final ValueChanged<String?> onInjuriesChanged;
  final VoidCallback onNoInjuries;
  final VoidCallback onSubmit;

  @override
  State<CheckInStepInjuries> createState() => _CheckInStepInjuriesState();
}

class _CheckInStepInjuriesState extends State<CheckInStepInjuries> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.injuriesNotes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Any injuries or pain?',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional — we\'ll adjust your plan if needed.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Describe any pain or injuries...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        onChanged: widget.onInjuriesChanged,
                      ),

                      const SizedBox(height: 16),

                      // Error display
                      if (widget.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            widget.error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // No injuries shortcut
                      OutlinedButton(
                        onPressed:
                            widget.isSubmitting ? null : widget.onNoInjuries,
                        child: const Text('No injuries — submit now'),
                      ),
                      const SizedBox(height: 12),

                      // Primary submit
                      FilledButton(
                        onPressed: widget.isSubmitting
                            ? null
                            : () {
                                widget.onInjuriesChanged(_controller.text);
                                widget.onSubmit();
                              },
                        child: widget.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
