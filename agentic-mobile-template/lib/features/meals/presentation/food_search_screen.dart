import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/food_database_service.dart';
import 'food_search_provider.dart';

// ── Food Search Screen ─────────────────────────────────────────────────────────

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode =
        await context.push<String>('/meals/food-barcode-scan');
    if (barcode == null || !mounted) return;

    final item =
        await ref.read(foodSearchProvider.notifier).lookupBarcode(barcode);
    if (!mounted) return;

    if (item != null) {
      context.pop(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No product found for this barcode')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodSearchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Food'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          ref
                              .read(foodSearchProvider.notifier)
                              .onQueryChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {}); // refresh suffix icon visibility
                ref.read(foodSearchProvider.notifier).onQueryChanged(v);
              },
            ),
          ),
          Expanded(child: _buildBody(state, theme)),
        ],
      ),
    );
  }

  Widget _buildBody(FoodSearchState state, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(state.error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref
                  .read(foodSearchProvider.notifier)
                  .onQueryChanged(state.query),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.food_bank_outlined,
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Search for a food or scan a barcode',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No results found for "${state.query}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) => _FoodResultTile(
        item: state.results[i],
        onTap: () => ctx.pop(state.results[i]),
      ),
    );
  }
}

// ── Result tile ────────────────────────────────────────────────────────────────

class _FoodResultTile extends StatelessWidget {
  const _FoodResultTile({required this.item, required this.onTap});

  final FoodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: item.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _FoodIconPlaceholder(theme),
              ),
            )
          : _FoodIconPlaceholder(theme),
      title: Text(
        item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.brand != null)
            Text(
              item.brand!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            item.macroSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.caloriesPer100g.toStringAsFixed(0),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            'kcal/100g',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FoodIconPlaceholder extends StatelessWidget {
  const _FoodIconPlaceholder(this.theme);
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.fastfood,
        color: theme.colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}

// ── Food Barcode Scanner ───────────────────────────────────────────────────────
// Lightweight scanner that pops back with the raw barcode string.

class FoodBarcodeScannerScreen extends StatefulWidget {
  const FoodBarcodeScannerScreen({super.key});

  @override
  State<FoodBarcodeScannerScreen> createState() =>
      _FoodBarcodeScannerScreenState();
}

class _FoodBarcodeScannerScreenState
    extends State<FoodBarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _done = false;

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

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    _done = true;
    context.pop(barcode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Scan Food Barcode'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: CustomPaint(
              painter: _FoodViewfinderPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align food barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxW = 270.0;
    const boxH = 160.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxW,
      height: boxH,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Semi-transparent overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
        path, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Corner accents
    const len = 22.0;
    final corner = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (final pts in [
      // top-left
      [Offset(rect.left, rect.top + len), Offset(rect.left, rect.top), Offset(rect.left + len, rect.top)],
      // top-right
      [Offset(rect.right - len, rect.top), Offset(rect.right, rect.top), Offset(rect.right, rect.top + len)],
      // bottom-left
      [Offset(rect.left, rect.bottom - len), Offset(rect.left, rect.bottom), Offset(rect.left + len, rect.bottom)],
      // bottom-right
      [Offset(rect.right - len, rect.bottom), Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - len)],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
