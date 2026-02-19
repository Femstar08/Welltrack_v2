import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/recipe_entity.dart';
import '../domain/recipe_step.dart';
import '../../meals/presentation/log_meal_screen.dart';

class PrepWalkthroughScreen extends ConsumerStatefulWidget {

  const PrepWalkthroughScreen({
    super.key,
    required this.recipe,
  });
  final RecipeEntity recipe;

  @override
  ConsumerState<PrepWalkthroughScreen> createState() => _PrepWalkthroughScreenState();
}

class _PrepWalkthroughScreenState extends ConsumerState<PrepWalkthroughScreen> {
  int _currentStepIndex = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  final Set<int> _completedSteps = {};
  final Set<int> _checkedIngredients = {};

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  RecipeStep get _currentStep => widget.recipe.steps[_currentStepIndex];

  void _startTimer(int minutes) {
    setState(() {
      _remainingSeconds = minutes * 60;
      _isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isTimerRunning = false;
          timer.cancel();
          _showTimerCompleteDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _isTimerRunning = false;
    });
  }

  void _showTimerCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.green),
            SizedBox(width: 8),
            Text('Timer Complete!'),
          ],
        ),
        content: Text('Step ${_currentStep.stepNumber} is done.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_currentStepIndex < widget.recipe.steps.length - 1) {
                _nextStep();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < widget.recipe.steps.length - 1) {
      setState(() {
        _completedSteps.add(_currentStepIndex);
        _currentStepIndex++;
        _resetTimer();
      });
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _resetTimer();
      });
    }
  }

  void _completePrep() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cooking Complete!'),
        content: const Text('Would you like to log this meal?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LogMealScreen(recipe: widget.recipe),
                ),
              );
            },
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_currentStepIndex + 1) / widget.recipe.steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
          ),
        ),
      ),
      body: Column(
        children: [
          // Step counter
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Step ${_currentStepIndex + 1} of ${widget.recipe.steps.length}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current step instruction
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _currentStep.instruction,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timer section
                  if (_currentStep.isTimed) ...[
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 32,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isTimerRunning || _remainingSeconds > 0
                                      ? _formatTime(_remainingSeconds)
                                      : '${_currentStep.durationMinutes} min',
                                  style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isTimerRunning && _remainingSeconds == 0)
                                  FilledButton.icon(
                                    onPressed: () => _startTimer(_currentStep.durationMinutes!),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start Timer'),
                                  ),
                                if (_isTimerRunning) ...[
                                  FilledButton.icon(
                                    onPressed: _pauseTimer,
                                    icon: const Icon(Icons.pause),
                                    label: const Text('Pause'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _resetTimer,
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Stop'),
                                  ),
                                ],
                                if (!_isTimerRunning && _remainingSeconds > 0) ...[
                                  FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isTimerRunning = true;
                                      });
                                      _timer = Timer.periodic(
                                        const Duration(seconds: 1),
                                        (timer) {
                                          setState(() {
                                            if (_remainingSeconds > 0) {
                                              _remainingSeconds--;
                                            } else {
                                              _isTimerRunning = false;
                                              timer.cancel();
                                              _showTimerCompleteDialog();
                                            }
                                          });
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _resetTimer,
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Reset'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Ingredients checklist
                  if (_currentStepIndex == 0) ...[
                    Text(
                      'Ingredients Checklist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: widget.recipe.ingredients.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ingredient = entry.value;
                          return CheckboxListTile(
                            title: Text(ingredient.displayText),
                            value: _checkedIngredients.contains(index),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _checkedIngredients.add(index);
                                } else {
                                  _checkedIngredients.remove(index);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Previous button
                  if (_currentStepIndex > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousStep,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                    ),
                  if (_currentStepIndex > 0) const SizedBox(width: 12),

                  // Next/Complete button
                  Expanded(
                    flex: 2,
                    child: _currentStepIndex < widget.recipe.steps.length - 1
                        ? FilledButton.icon(
                            onPressed: _nextStep,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next Step'),
                          )
                        : FilledButton.icon(
                            onPressed: _completePrep,
                            icon: const Icon(Icons.check),
                            label: const Text('Complete'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
