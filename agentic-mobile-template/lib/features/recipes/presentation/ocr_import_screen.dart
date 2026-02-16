import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Stub screen for OCR recipe import from photos
///
/// This screen provides the UI structure for importing recipes
/// from photos using OCR (Optical Character Recognition).
/// The actual Vision API integration will be implemented in a future update.
class OcrImportScreen extends ConsumerStatefulWidget {
  const OcrImportScreen({super.key});

  @override
  ConsumerState<OcrImportScreen> createState() => _OcrImportScreenState();
}

class _OcrImportScreenState extends ConsumerState<OcrImportScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
      _showComingSoonDialog();
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
      setState(() {
        _selectedImage = image;
      });
      _showComingSoonDialog();
    }
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text(
          'Photo OCR recipe import is coming in a future update!\n\n'
          'This feature will use Vision API to extract recipe details '
          'from photos of cookbooks, recipe cards, or screenshots.\n\n'
          'For now, you can use URL import to add recipes from websites.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Photo'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.5),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.camera_alt,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('Take Photo'),
                          subtitle: const Text('Capture a recipe with your camera'),
                          onTap: _captureFromCamera,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(
                            Icons.photo_library,
                            color: theme.colorScheme.primary,
                          ),
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
                Text(
                  'How it works',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildHowItWorksStep(
                  context,
                  1,
                  'Capture or Select',
                  'Take a photo of a recipe from a cookbook, magazine, or recipe card',
                ),
                _buildHowItWorksStep(
                  context,
                  2,
                  'AI Extracts Details',
                  'Our AI reads the recipe and extracts ingredients, steps, and cooking times',
                ),
                _buildHowItWorksStep(
                  context,
                  3,
                  'Review & Save',
                  'Review the extracted recipe, make any edits, and save it to your collection',
                ),
                const SizedBox(height: 32),

                // Tips card
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: theme.colorScheme.primary,
                            ),
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
                const SizedBox(height: 24),

                // Supported sources
                Text(
                  'Supported sources',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSourceChip(context, 'Cookbooks'),
                    _buildSourceChip(context, 'Recipe Cards'),
                    _buildSourceChip(context, 'Magazines'),
                    _buildSourceChip(context, 'Screenshots'),
                    _buildSourceChip(context, 'Handwritten Notes'),
                  ],
                ),
              ],
            ),
          ),

          // Coming soon overlay (semi-transparent)
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface.withOpacity(0.9),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.construction,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Coming Soon',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Photo OCR recipe import is under development and will be available in a future update.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(
    BuildContext context,
    int step,
    String title,
    String description,
  ) {
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
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildSourceChip(BuildContext context, String label) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
