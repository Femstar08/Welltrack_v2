import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'photo_shopping_import_provider.dart';
import 'shopping_list_provider.dart';

class PhotoShoppingImportScreen extends ConsumerStatefulWidget {
  const PhotoShoppingImportScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<PhotoShoppingImportScreen> createState() =>
      _PhotoShoppingImportScreenState();
}

class _PhotoShoppingImportScreenState
    extends ConsumerState<PhotoShoppingImportScreen> {
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
      await ref
          .read(photoShoppingImportProvider.notifier)
          .processImage(image.path);
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
      await ref
          .read(photoShoppingImportProvider.notifier)
          .processImage(image.path);
    }
  }

  Future<void> _saveItems() async {
    final count = await ref
        .read(photoShoppingImportProvider.notifier)
        .saveSelectedItems(widget.listId);

    if (count > 0 && mounted) {
      ref.invalidate(shoppingListDetailProvider(widget.listId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $count items to shopping list')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoShoppingImportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Shopping Items'),
      ),
      body: switch (state.status) {
        PhotoShoppingImportStatus.idle => _buildCaptureView(theme, state),
        PhotoShoppingImportStatus.processing => _buildProcessingView(theme),
        PhotoShoppingImportStatus.review => _buildReviewView(theme, state),
        PhotoShoppingImportStatus.saving => _buildSavingView(theme),
      },
    );
  }

  Widget _buildCaptureView(ThemeData theme, PhotoShoppingImportState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.shopping_cart,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan Shopping Items',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Photograph a handwritten list or printed list to quickly add items',
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
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
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
                    leading:
                        Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                    title: const Text('Take Photo'),
                    subtitle: const Text('Capture a shopping list'),
                    onTap: _captureFromCamera,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.photo_library,
                        color: theme.colorScheme.primary),
                    title: const Text('Choose from Gallery'),
                    subtitle: const Text('Select an existing photo'),
                    onTap: _pickFromGallery,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView(ThemeData theme) {
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
          Text(
            'Scanning items...',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView(ThemeData theme, PhotoShoppingImportState state) {
    return Column(
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),

        // Item count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.selectedCount} of ${state.items.length} items selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: _captureFromCamera,
                child: const Text('Re-scan'),
              ),
            ],
          ),
        ),

        // Editable item list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return Dismissible(
                key: ValueKey('shopping_item_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: theme.colorScheme.error,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref
                      .read(photoShoppingImportProvider.notifier)
                      .removeItem(index);
                },
                child: CheckboxListTile(
                  value: item.isSelected,
                  onChanged: (_) {
                    ref
                        .read(photoShoppingImportProvider.notifier)
                        .toggleItem(index);
                  },
                  title: Text(item.name),
                  subtitle: Text(
                    [
                      if (item.quantity != null) item.quantity.toString(),
                      if (item.unit != null) item.unit!,
                      item.aisle,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              );
            },
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: state.selectedCount > 0 ? _saveItems : null,
            icon: const Icon(Icons.add),
            label: Text('Add ${state.selectedCount} items'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingView(ThemeData theme) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Saving items...'),
        ],
      ),
    );
  }
}
