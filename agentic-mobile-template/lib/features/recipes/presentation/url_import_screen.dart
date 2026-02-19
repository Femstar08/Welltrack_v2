import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/recipe_repository.dart';
import '../data/url_recipe_extractor.dart';
import '../domain/recipe_entity.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/auth_state.dart';
import '../../profile/presentation/profile_provider.dart';

/// State for URL import
class UrlImportState {

  const UrlImportState({
    this.isLoading = false,
    this.extractedRecipe,
    this.error,
  });
  final bool isLoading;
  final RecipeEntity? extractedRecipe;
  final String? error;

  UrlImportState copyWith({
    bool? isLoading,
    RecipeEntity? extractedRecipe,
    String? error,
  }) {
    return UrlImportState(
      isLoading: isLoading ?? this.isLoading,
      extractedRecipe: extractedRecipe ?? this.extractedRecipe,
      error: error,
    );
  }
}

/// Controller for URL recipe import
class UrlImportController extends StateNotifier<UrlImportState> {

  UrlImportController(
    this._extractor,
    this._repository,
    this._userId,
    this._profileId,
  ) : super(const UrlImportState());
  final UrlRecipeExtractor _extractor;
  final RecipeRepository _repository;
  final String _userId;
  final String _profileId;

  /// Extract recipe from URL
  Future<void> extractRecipe(String url) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final recipe = await _extractor.extractRecipe(
        url: url,
        userId: _userId,
        profileId: _profileId,
      );

      state = state.copyWith(
        isLoading: false,
        extractedRecipe: recipe,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Save the extracted recipe
  Future<bool> saveRecipe(RecipeEntity recipe) async {
    state = state.copyWith(isLoading: true, error: null);

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
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save recipe: ${e.toString()}',
      );
      return false;
    }
  }

  /// Update the extracted recipe (for editing)
  void updateRecipe(RecipeEntity recipe) {
    state = state.copyWith(extractedRecipe: recipe);
  }

  /// Clear the current state
  void clear() {
    state = const UrlImportState();
  }
}

/// Provider for URL import controller
final urlImportControllerProvider =
    StateNotifierProvider.autoDispose<UrlImportController, UrlImportState>((ref) {
  final extractor = ref.watch(urlRecipeExtractorProvider);
  final repository = ref.watch(recipeRepositoryProvider);
  final authState = ref.watch(authProvider);
  final profileAsync = ref.watch(activeProfileProvider);

  final userId = authState is AuthAuthenticated ? authState.user.id : '';
  final profileId = profileAsync.valueOrNull?.id ?? '';

  return UrlImportController(extractor, repository, userId, profileId);
});

/// Screen for importing recipes from URLs
class UrlImportScreen extends ConsumerStatefulWidget {
  const UrlImportScreen({super.key});

  @override
  ConsumerState<UrlImportScreen> createState() => _UrlImportScreenState();
}

class _UrlImportScreenState extends ConsumerState<UrlImportScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  Future<void> _extractRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(urlImportControllerProvider.notifier).extractRecipe(_urlController.text);
  }

  Future<void> _saveRecipe() async {
    final state = ref.read(urlImportControllerProvider);
    if (state.extractedRecipe == null) return;

    final success = await ref.read(urlImportControllerProvider.notifier).saveRecipe(state.extractedRecipe!);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved successfully!')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(urlImportControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Recipe from URL'),
      ),
      body: state.extractedRecipe == null
          ? _buildUrlInput(theme, state)
          : _buildRecipePreview(theme, state),
    );
  }

  Widget _buildUrlInput(ThemeData theme, UrlImportState state) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste a recipe URL',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll extract the recipe details automatically',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Recipe URL',
                hintText: 'https://example.com/recipe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste from clipboard',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a URL';
                }
                final uri = Uri.tryParse(value);
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _extractRecipe(),
            ),
            const SizedBox(height: 24),
            if (state.error != null)
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
            ElevatedButton(
              onPressed: state.isLoading ? null : _extractRecipe,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Extract Recipe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipePreview(ThemeData theme, UrlImportState state) {
    final recipe = state.extractedRecipe!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recipe Preview',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Review and edit the extracted recipe',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.headlineSmall,
                  ),
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
                      if (recipe.totalTimeMin != null)
                        const SizedBox(width: 8),
                      _buildInfoChip(Icons.signal_cellular_alt, recipe.difficultyLevel),
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
          if (state.error != null)
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isLoading ? null : () {
                    ref.read(urlImportControllerProvider.notifier).clear();
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _saveRecipe,
                  child: state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Recipe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: null, // Stub for future implementation
            icon: const Icon(Icons.calendar_today),
            label: const Text('Add to Plan'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: null, // Stub for future implementation
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Generate Shopping List'),
          ),
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
