import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../data/ocr_recipe_extractor.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe_entity.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/auth_state.dart';
import '../../profile/presentation/profile_provider.dart';

/// State for the OCR recipe import flow.
enum OcrImportStatus { idle, ocrProcessing, aiProcessing, preview, saving }

class OcrImportState {
  const OcrImportState({
    this.status = OcrImportStatus.idle,
    this.extractedRecipe,
    this.error,
  });

  final OcrImportStatus status;
  final RecipeEntity? extractedRecipe;
  final String? error;

  OcrImportState copyWith({
    OcrImportStatus? status,
    RecipeEntity? extractedRecipe,
    String? error,
  }) {
    return OcrImportState(
      status: status ?? this.status,
      extractedRecipe: extractedRecipe ?? this.extractedRecipe,
      error: error,
    );
  }
}

/// Controller for OCR recipe import.
class OcrImportController extends StateNotifier<OcrImportState> {
  OcrImportController(this._extractor, this._repository, this._userId, this._profileId)
      : super(const OcrImportState());

  final OcrRecipeExtractor _extractor;
  final RecipeRepository _repository;
  final String _userId;
  final String _profileId;

  Future<void> processImage(String imagePath) async {
    state = state.copyWith(
      status: OcrImportStatus.ocrProcessing,
      error: null,
    );

    try {
      // The extractor handles both OCR and AI steps internally,
      // but we show ai_processing status after a short delay.
      state = state.copyWith(status: OcrImportStatus.aiProcessing);

      final recipe = await _extractor.extractRecipe(
        imagePath: imagePath,
        userId: _userId,
        profileId: _profileId,
      );

      state = state.copyWith(
        status: OcrImportStatus.preview,
        extractedRecipe: recipe,
      );
    } catch (e) {
      state = state.copyWith(
        status: OcrImportStatus.idle,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> saveRecipe() async {
    final recipe = state.extractedRecipe;
    if (recipe == null) return false;

    state = state.copyWith(status: OcrImportStatus.saving, error: null);

    try {
      await _repository.saveRecipe(
        profileId: recipe.profileId,
        title: recipe.title,
        description: recipe.description,
        servings: recipe.servings,
        prepTimeMin: recipe.prepTimeMin,
        cookTimeMin: recipe.cookTimeMin,
        sourceType: recipe.sourceType,
        sourceUrl: recipe.sourceUrl,
        nutritionScore: recipe.nutritionScore,
        tags: recipe.tags,
        imageUrl: recipe.imageUrl,
        steps: recipe.steps,
        ingredients: recipe.ingredients,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: OcrImportStatus.preview,
        error: 'Failed to save: ${e.toString()}',
      );
      return false;
    }
  }

  void reset() {
    state = const OcrImportState();
  }
}

/// Provider for [OcrImportController].
final ocrImportControllerProvider =
    StateNotifierProvider.autoDispose<OcrImportController, OcrImportState>((ref) {
  final extractor = ref.watch(ocrRecipeExtractorProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  final authState = ref.watch(authProvider);
  final profileAsync = ref.watch(activeProfileProvider);

  final userId = authState is AuthAuthenticated ? authState.user.id : '';
  final profileId = profileAsync.valueOrNull?.id ?? '';

  return OcrImportController(extractor, repository, userId, profileId);
});

/// Screen for importing recipes via photo OCR + AI.
class OcrImportScreen extends ConsumerStatefulWidget {
  const OcrImportScreen({super.key});

  @override
  ConsumerState<OcrImportScreen> createState() => _OcrImportScreenState();
}

class _OcrImportScreenState extends ConsumerState<OcrImportScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _imagePath;

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
      await ref.read(ocrImportControllerProvider.notifier).processImage(image.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _imagePath = image.path);
      await ref.read(ocrImportControllerProvider.notifier).processImage(image.path);
    }
  }

  Future<void> _saveRecipe() async {
    final success =
        await ref.read(ocrImportControllerProvider.notifier).saveRecipe();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved successfully!')),
      );
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ocrImportControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Photo'),
      ),
      body: switch (state.status) {
        OcrImportStatus.idle => _buildCaptureView(theme, state),
        OcrImportStatus.ocrProcessing => _buildProcessingView(theme, 'Reading text from image...'),
        OcrImportStatus.aiProcessing => _buildProcessingView(theme, 'AI is parsing recipe details...'),
        OcrImportStatus.preview => _buildPreviewView(theme, state),
        OcrImportStatus.saving => _buildProcessingView(theme, 'Saving recipe...'),
      },
    );
  }

  Widget _buildCaptureView(ThemeData theme, OcrImportState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.camera_alt,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Import Recipe from Photo',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Snap a photo of a recipe or choose one from your gallery',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                    title: const Text('Take Photo'),
                    subtitle: const Text('Capture a recipe with your camera'),
                    onTap: _captureFromCamera,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.photo_library, color: theme.colorScheme.primary),
                    title: const Text('Choose from Gallery'),
                    subtitle: const Text('Select an existing photo'),
                    onTap: _pickFromGallery,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // How it works
          Text('How it works', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          _buildHowItWorksStep(context, 1, 'Capture or Select',
              'Take a photo of a recipe from a cookbook, magazine, or recipe card'),
          _buildHowItWorksStep(context, 2, 'AI Extracts Details',
              'On-device OCR reads the text, then AI parses ingredients, steps, and times'),
          _buildHowItWorksStep(context, 3, 'Review & Save',
              'Review the extracted recipe, make any edits, and save it to your collection'),
          const SizedBox(height: 32),

          // Tips
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for best results',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('Ensure good lighting and focus'),
                  _buildTip('Capture the entire recipe in frame'),
                  _buildTip('Use clear, high-resolution images'),
                  _buildTip('Avoid shadows and reflections'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_imagePath!),
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
          ],
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildPreviewView(ThemeData theme, OcrImportState state) {
    final recipe = state.extractedRecipe!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recipe Preview', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Review the extracted recipe',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Image thumbnail
          if (_imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_imagePath!),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, style: theme.textTheme.headlineSmall),
                  if (recipe.description != null) ...[
                    const SizedBox(height: 8),
                    Text(recipe.description!),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(Icons.people, '${recipe.servings} servings'),
                      const SizedBox(width: 8),
                      if (recipe.totalTimeMin != null)
                        _buildInfoChip(Icons.timer, '${recipe.totalTimeMin} min'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Ingredients', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...recipe.ingredients.map((ing) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(ing.displayText)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Steps', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...recipe.steps.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${entry.key + 1}. '),
                            Expanded(child: Text(entry.value.instruction)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(ocrImportControllerProvider.notifier).reset();
                    setState(() => _imagePath = null);
                  },
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saveRecipe,
                  child: const Text('Save Recipe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(
      BuildContext context, int step, String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              step.toString(),
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(tip)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
