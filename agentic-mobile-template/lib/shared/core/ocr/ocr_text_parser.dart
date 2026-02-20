/// A parsed item extracted from OCR text, with optional quantity and unit.
class ParsedItem {
  const ParsedItem({
    required this.name,
    this.quantity,
    this.unit,
  });

  final String name;
  final double? quantity;
  final String? unit;

  @override
  String toString() => [
        if (quantity != null) quantity.toString(),
        if (unit != null) unit,
        name,
      ].join(' ');
}

/// Static utilities for cleaning and parsing OCR text into structured items.
class OcrTextParser {
  OcrTextParser._();

  /// Common units that might appear before an item name.
  static const _unitPatterns = [
    'kg', 'g', 'mg', 'lb', 'lbs', 'oz',
    'l', 'ml', 'cl', 'dl',
    'cup', 'cups', 'tbsp', 'tsp', 'tablespoon', 'teaspoon',
    'pcs', 'pc', 'piece', 'pieces', 'pack', 'packs', 'bunch',
    'can', 'cans', 'jar', 'jars', 'bottle', 'bottles', 'bag', 'bags',
    'box', 'boxes', 'packet', 'packets', 'tin', 'tins',
  ];

  /// Regex: optional leading quantity (int or decimal), optional unit, then the item name.
  static final _quantityLineRegex = RegExp(
    r'^(\d+\.?\d*)\s*(' + _unitPatterns.join('|') + r')?\s+(.+)$',
    caseSensitive: false,
  );

  /// Patterns that indicate receipt noise rather than real items.
  static final _noisePatterns = [
    RegExp(r'^\$?\d+\.\d{2}$'),                     // Prices like $4.99 or 4.99
    RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$'),  // Dates
    RegExp(r'^(total|subtotal|tax|change|cash|card|visa|mastercard|receipt)', caseSensitive: false),
    RegExp(r'^(thank|welcome|store|tel|phone|address|www\.|http)', caseSensitive: false),
    RegExp(r'^\d{5,}$'),                              // Long numbers (barcodes, etc.)
    RegExp(r'^[#*\-=]{3,}$'),                         // Separator lines
    RegExp(r'^\s*$'),                                  // Blank lines
  ];

  /// Parses a list of OCR lines into structured [ParsedItem]s.
  ///
  /// Filters out receipt noise (prices, dates, totals, headers) and
  /// attempts to extract quantity + unit from the beginning of each line.
  static List<ParsedItem> parseAsItemList(List<String> lines) {
    final items = <ParsedItem>[];

    for (final raw in lines) {
      final line = cleanOcrText(raw);
      if (line.isEmpty) continue;

      // Skip noise
      if (_isNoiseLine(line)) continue;

      // Skip very short lines (likely OCR fragments)
      if (line.length < 2) continue;

      // Try to extract quantity + unit
      final match = _quantityLineRegex.firstMatch(line);
      if (match != null) {
        final qty = double.tryParse(match.group(1)!);
        final unit = match.group(2);
        final name = _capitalizeFirst(match.group(3)!.trim());
        if (name.isNotEmpty) {
          items.add(ParsedItem(name: name, quantity: qty, unit: unit));
          continue;
        }
      }

      // Strip a leading bullet/dash/number marker
      final cleaned = line
          .replaceFirst(RegExp(r'^[\-\*\u2022\u25CF\u25CB]\s*'), '')
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
          .trim();

      if (cleaned.isNotEmpty && cleaned.length >= 2) {
        items.add(ParsedItem(name: _capitalizeFirst(cleaned)));
      }
    }

    return items;
  }

  /// Normalizes OCR whitespace and strips common artifacts.
  static String cleanOcrText(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')  // Collapse whitespace
        .replaceAll(RegExp(r'[|]'), '')    // Remove pipe artifacts
        .trim();
  }

  static bool _isNoiseLine(String line) {
    return _noisePatterns.any((p) => p.hasMatch(line));
  }

  static String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
