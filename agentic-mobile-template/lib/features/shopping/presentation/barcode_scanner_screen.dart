import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../shared/core/router/app_router.dart';
import '../domain/shopping_list_item_entity.dart';
import 'barcode_scan_provider.dart';
import 'shopping_list_provider.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.listId,
    required this.items,
  });

  final String listId;
  final List<ShoppingListItemEntity> items;

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _sheetOpen = false;

  ({String listId, List<ShoppingListItemEntity> items}) get _params =>
      (listId: widget.listId, items: widget.items);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_sheetOpen) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _sheetOpen = true;
    try {
      await _controller.stop();
    } catch (_) {
      // Controller may already be stopped
    }

    // Trigger lookup immediately (sheet shows loading state)
    ref
        .read(barcodeScanWithItemsProvider(_params).notifier)
        .onBarcodeScanned(barcode!.rawValue!);

    if (!mounted) return;
    await _showResultSheet();
  }

  Future<void> _showResultSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResultSheet(params: _params),
    );

    _sheetOpen = false;
    if (!mounted) return;

    // Read success message BEFORE reset
    final state = ref.read(barcodeScanWithItemsProvider(_params));
    final successMsg = state.successMessage;

    if (successMsg != null) {
      ref.invalidate(shoppingListDetailProvider(widget.listId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    ref.read(barcodeScanWithItemsProvider(_params).notifier).reset();

    try {
      await _controller.start();
    } catch (_) {
      // Controller may already be running or disposed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          const _ViewfinderOverlay(),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewfinder overlay ────────────────────────────────────────────────────────

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ViewfinderPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double boxWidth = 270;
    const double boxHeight = 160;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: boxWidth, height: boxHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Semi-transparent overlay with cutout
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // White border around viewfinder
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, border);

    // Green corner accents
    _drawCorners(canvas, rect);
  }

  void _drawCorners(Canvas canvas, Rect rect) {
    const len = 22.0;
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final corners = [
      // Top-left
      [
        Offset(rect.left, rect.top + len),
        Offset(rect.left, rect.top),
        Offset(rect.left + len, rect.top)
      ],
      // Top-right
      [
        Offset(rect.right - len, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + len)
      ],
      // Bottom-left
      [
        Offset(rect.left, rect.bottom - len),
        Offset(rect.left, rect.bottom),
        Offset(rect.left + len, rect.bottom)
      ],
      // Bottom-right
      [
        Offset(rect.right - len, rect.bottom),
        Offset(rect.right, rect.bottom),
        Offset(rect.right, rect.bottom - len)
      ],
    ];

    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Result bottom sheet ───────────────────────────────────────────────────────

class _ResultSheet extends ConsumerStatefulWidget {
  const _ResultSheet({required this.params});

  final ({String listId, List<ShoppingListItemEntity> items}) params;

  @override
  ConsumerState<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends ConsumerState<_ResultSheet> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final profileId = ref.read(activeProfileIdProvider) ?? '';
    await ref
        .read(barcodeScanWithItemsProvider(widget.params).notifier)
        .confirm(profileId: profileId);

    if (!mounted) return;
    final state = ref.read(barcodeScanWithItemsProvider(widget.params));
    if (state.error == null && state.successMessage != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(barcodeScanWithItemsProvider(widget.params));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Loading state
          if (state.isLookingUp) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Text(
              'Looking up product...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Product info or manual input (shown after lookup)
          if (!state.isLookingUp) ...[
            if (state.productInfo?.productName != null) ...[
              // Known product
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.productInfo!.productName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (state.productInfo!.brand != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            state.productInfo!.brand!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (state.productInfo!.quantity != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            state.productInfo!.quantity!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (state.productInfo!.calories != null)
                    Chip(
                      label: Text(
                        '${state.productInfo!.calories!.toStringAsFixed(0)} kcal/100g',
                        style: theme.textTheme.labelSmall,
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ] else ...[
              // Unknown product — text field for manual name
              Text(
                'Unknown product${state.scannedBarcode != null ? ' · ${state.scannedBarcode}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  hintText: 'Enter product name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  ref
                      .read(barcodeScanWithItemsProvider(widget.params).notifier)
                      .setManualName(value);
                },
              ),
            ],

            const SizedBox(height: 12),

            // Fuzzy-matched shopping list item
            if (state.matchedItemIndex != null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Matches: ', style: theme.textTheme.bodySmall),
                  Flexible(
                    child: Chip(
                      label: Text(
                        widget.params.items[state.matchedItemIndex!]
                            .ingredientName,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Category picker
            Text('Category', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'fridge',
                  label: Text('Fridge'),
                  icon: Icon(Icons.kitchen, size: 16),
                ),
                ButtonSegment(
                  value: 'cupboard',
                  label: Text('Cupboard'),
                  icon: Icon(Icons.inventory_2, size: 16),
                ),
                ButtonSegment(
                  value: 'freezer',
                  label: Text('Freezer'),
                  icon: Icon(Icons.ac_unit, size: 16),
                ),
              ],
              selected: {state.selectedCategory},
              onSelectionChanged: (selection) {
                ref
                    .read(barcodeScanWithItemsProvider(widget.params).notifier)
                    .setCategory(selection.first);
              },
            ),

            const SizedBox(height: 12),

            // Quantity stepper
            Row(
              children: [
                Text('Quantity', style: theme.textTheme.labelMedium),
                const Spacer(),
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed: state.quantity > 1
                      ? () => ref
                          .read(barcodeScanWithItemsProvider(widget.params)
                              .notifier)
                          .setQuantity(state.quantity - 1)
                      : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '${state.quantity}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: state.quantity < 99
                      ? () => ref
                          .read(barcodeScanWithItemsProvider(widget.params)
                              .notifier)
                          .setQuantity(state.quantity + 1)
                      : null,
                ),
              ],
            ),

            // Error display
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            FilledButton(
              onPressed: state.isConfirming ? null : _confirm,
              child: state.isConfirming
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add to Pantry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}
