import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';

/// Client-side recipe extractor that parses structured data from HTML pages.
///
/// Strategy:
///   1. Fetch the URL with a browser-like User-Agent using a dedicated Dio
///      instance (NOT the app DioClient which points at Supabase).
///   2. Parse all <script type="application/ld+json"> blocks looking for a
///      schema.org Recipe object (possibly nested inside @graph).
///   3. Map the JSON-LD fields to [RecipeEntity], [RecipeIngredient], and
///      [RecipeStep].
///
/// Throws a descriptive [Exception] when no recipe data can be found.
class HtmlRecipeExtractor {
  HtmlRecipeExtractor() : _dio = _buildDio();

  final Dio _dio;

  /// Builds a fresh Dio instance with browser-like headers.
  /// The connect/receive timeouts are deliberately generous because recipe
  /// sites can be slow.
  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; WellTrack/1.0)',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
        // Receive as plain text so we can search the HTML ourselves
        responseType: ResponseType.plain,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetches [url] and attempts to extract a recipe from the page HTML.
  ///
  /// [profileId] is embedded in the returned entity.
  ///
  /// Throws [ArgumentError] for a malformed URL, or a descriptive [Exception]
  /// when the page contains no recognisable recipe data.
  Future<RecipeEntity> extractRecipe({
    required String url,
    required String profileId,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Invalid URL format: $url');
    }

    late final String html;
    try {
      final response = await _dio.get<String>(url);
      html = response.data ?? '';
    } on DioException catch (e) {
      throw Exception(
        'Could not fetch the recipe page: ${e.message ?? e.type.name}',
      );
    }

    if (html.isEmpty) {
      throw Exception('The recipe page returned an empty response.');
    }

    // Primary strategy: JSON-LD structured data
    final recipeJson = _findRecipeJsonLd(html);
    if (recipeJson != null) {
      return _mapJsonLdToEntity(recipeJson, url, profileId);
    }

    // Fallback: meta-tag / microdata heuristics
    final metaRecipe = _extractFromMetaTags(html, url, profileId);
    if (metaRecipe != null) {
      return metaRecipe;
    }

    throw Exception(
      'No recipe data found on this page. '
      'The site may not use schema.org markup. '
      'Try a different recipe site or enter the recipe manually.',
    );
  }

  // ---------------------------------------------------------------------------
  // JSON-LD parsing
  // ---------------------------------------------------------------------------

  /// Scans all <script type="application/ld+json"> blocks in [html] and
  /// returns the first JSON object whose @type contains "Recipe".
  Map<String, dynamic>? _findRecipeJsonLd(String html) {
    // Extract all ld+json script block contents
    final scriptRegex = RegExp(
      r"""<script[^>]+type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>""",
      caseSensitive: false,
    );

    for (final match in scriptRegex.allMatches(html)) {
      final content = match.group(1)?.trim();
      if (content == null || content.isEmpty) continue;

      dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } catch (_) {
        // Malformed JSON — skip this block
        continue;
      }

      // The block may be a single object or an array of objects
      final candidates = decoded is List ? decoded : [decoded];

      for (final candidate in candidates) {
        if (candidate is! Map<String, dynamic>) continue;

        // Some sites wrap everything in a @graph array
        if (candidate.containsKey('@graph')) {
          final graph = candidate['@graph'];
          if (graph is List) {
            for (final node in graph) {
              if (node is Map<String, dynamic> && _isRecipeType(node)) {
                return node;
              }
            }
          }
        }

        if (_isRecipeType(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }

  /// Returns true when [json] has an @type that equals or contains "Recipe".
  bool _isRecipeType(Map<String, dynamic> json) {
    final type = json['@type'];
    if (type == null) return false;
    if (type is String) return type == 'Recipe';
    if (type is List) {
      return type.any((t) => t is String && t == 'Recipe');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // JSON-LD → RecipeEntity mapping
  // ---------------------------------------------------------------------------

  RecipeEntity _mapJsonLdToEntity(
    Map<String, dynamic> json,
    String url,
    String profileId,
  ) {
    final title = _stringValue(json, 'name') ?? 'Untitled Recipe';
    final description = _stringValue(json, 'description');
    final imageUrl = _extractImageUrl(json['image']);
    final prepTimeMin = _parseDuration(json['prepTime']);
    final cookTimeMin = _parseDuration(json['cookTime']);
    final servings = _parseServings(json['recipeYield']);
    final tags = _extractTags(json);
    final ingredients = _parseIngredients(json['recipeIngredient']);
    final steps = _parseSteps(json['recipeInstructions']);

    return RecipeEntity(
      id: '',
      profileId: profileId,
      title: title,
      description: description,
      servings: servings,
      prepTimeMin: prepTimeMin,
      cookTimeMin: cookTimeMin,
      sourceType: 'url',
      sourceUrl: url,
      nutritionScore: null,
      tags: tags,
      imageUrl: imageUrl,
      ingredients: ingredients,
      steps: steps,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Field extractors
  // ---------------------------------------------------------------------------

  /// Reads a field as a plain string, handling both String and Map cases.
  String? _stringValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    // Some sites nest the text in {"@value": "..."} or {"text": "..."}
    if (value is Map<String, dynamic>) {
      final inner = value['@value'] ?? value['text'];
      if (inner is String) return inner.trim().isEmpty ? null : inner.trim();
    }
    return null;
  }

  /// Extracts the best image URL from various schema.org image representations:
  ///   - A plain String
  ///   - An ImageObject map with a "url" field
  ///   - An array of either of the above (first item is taken)
  String? _extractImageUrl(dynamic image) {
    if (image == null) return null;
    if (image is String) return image.trim().isEmpty ? null : image.trim();
    if (image is Map<String, dynamic>) {
      final url = image['url'] ?? image['contentUrl'];
      if (url is String) return url.trim().isEmpty ? null : url.trim();
    }
    if (image is List && image.isNotEmpty) {
      return _extractImageUrl(image.first);
    }
    return null;
  }

  /// Parses an ISO 8601 duration string (e.g. "PT1H30M") into whole minutes.
  ///
  /// Supports:
  ///   PT30M  → 30
  ///   PT1H   → 60
  ///   PT1H30M → 90
  ///   P1DT2H → 1500  (1 day + 2 hours; unusual but handled)
  int? _parseDuration(dynamic value) {
    if (value == null) return null;
    final raw = value is String ? value : value.toString();
    if (raw.isEmpty) return null;

    var total = 0;
    // Days
    final dayMatch = RegExp(r'(\d+)D', caseSensitive: false).firstMatch(raw);
    if (dayMatch != null) total += int.parse(dayMatch.group(1)!) * 24 * 60;
    // Hours
    final hourMatch = RegExp(r'(\d+)H', caseSensitive: false).firstMatch(raw);
    if (hourMatch != null) total += int.parse(hourMatch.group(1)!) * 60;
    // Minutes
    final minMatch = RegExp(r'(\d+)M', caseSensitive: false).firstMatch(raw);
    if (minMatch != null) total += int.parse(minMatch.group(1)!);

    return total > 0 ? total : null;
  }

  /// Parses recipeYield into a whole-number serving count.
  ///
  /// Handles:
  ///   "4 servings" → 4
  ///   "4"          → 4
  ///   ["4 servings"] → 4
  ///   4            → 4
  int _parseServings(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value > 0 ? value : 1;
    if (value is double) return value > 0 ? value.round() : 1;

    String raw;
    if (value is List) {
      if (value.isEmpty) return 1;
      raw = value.first.toString();
    } else {
      raw = value.toString();
    }

    // Pull the first integer from the string ("4 servings" → 4)
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match != null) {
      final n = int.tryParse(match.group(0)!);
      if (n != null && n > 0) return n;
    }

    return 1;
  }

  /// Builds a flat list of tags from recipeCategory, recipeCuisine, and
  /// keywords, deduplicating and lower-casing everything.
  List<String> _extractTags(Map<String, dynamic> json) {
    final tagSet = <String>{};

    void addRaw(dynamic raw) {
      if (raw == null) return;
      if (raw is String) {
        // keywords can be comma-separated
        for (final part in raw.split(',')) {
          final t = part.trim().toLowerCase();
          if (t.isNotEmpty) tagSet.add(t);
        }
      } else if (raw is List) {
        for (final item in raw) {
          addRaw(item);
        }
      }
    }

    addRaw(json['recipeCategory']);
    addRaw(json['recipeCuisine']);
    addRaw(json['keywords']);

    return tagSet.toList();
  }

  /// Parses the recipeIngredient field (always a string array in schema.org)
  /// into a list of [RecipeIngredient].
  ///
  /// The raw strings are kept whole in [ingredientName]; quantity/unit parsing
  /// is done with a best-effort regex split so users can still edit later.
  List<RecipeIngredient> _parseIngredients(dynamic value) {
    if (value == null) return [];

    final rawList = value is List ? value : [value];
    final result = <RecipeIngredient>[];

    for (var i = 0; i < rawList.length; i++) {
      final raw = rawList[i]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;

      // Best-effort: try to split "2 cups flour" into quantity + unit + name
      final parsed = _splitIngredientString(raw);

      result.add(
        RecipeIngredient(
          id: '',
          ingredientName: parsed.name,
          quantity: parsed.quantity,
          unit: parsed.unit,
          sortOrder: i,
        ),
      );
    }

    return result;
  }

  /// Parses recipeInstructions into a list of [RecipeStep].
  ///
  /// Handles:
  ///   - Array of HowToStep objects: [{"@type": "HowToStep", "text": "..."}]
  ///   - Array of strings: ["Step 1...", "Step 2..."]
  ///   - A single string (may contain newlines)
  List<RecipeStep> _parseSteps(dynamic value) {
    if (value == null) return [];

    List<dynamic> items;

    if (value is String) {
      // Single multi-line string: split on newlines or numbered markers
      items = value
          .split(RegExp(r'\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (value is List) {
      items = value;
    } else {
      return [];
    }

    final result = <RecipeStep>[];
    var stepNumber = 1;

    for (final item in items) {
      String? text;

      if (item is String) {
        text = item.trim();
      } else if (item is Map<String, dynamic>) {
        // HowToStep or HowToSection
        final type = item['@type'];
        if (type == 'HowToSection') {
          // HowToSection has an "itemListElement" array of HowToSteps
          final subSteps = _parseSteps(item['itemListElement']);
          for (final sub in subSteps) {
            result.add(
              RecipeStep(
                id: '',
                stepNumber: stepNumber++,
                instruction: sub.instruction,
                durationMinutes: sub.durationMinutes,
              ),
            );
          }
          continue;
        }

        // HowToStep: prefer "text" over "name" (name can be a short label)
        text = (item['text'] ?? item['name'])?.toString().trim();
      }

      if (text == null || text.isEmpty) continue;

      // Strip leading numbering like "1. " or "Step 1: "
      text = text.replaceFirst(
        RegExp(r'^(?:step\s*)?\d+[.:)]\s*', caseSensitive: false),
        '',
      );
      if (text.isEmpty) continue;

      result.add(
        RecipeStep(
          id: '',
          stepNumber: stepNumber++,
          instruction: text,
          durationMinutes: null,
        ),
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Ingredient string splitter
  // ---------------------------------------------------------------------------

  _ParsedIngredient _splitIngredientString(String raw) {
    // Matches an optional leading number (int or fraction like 1/2 or 1 1/2)
    // followed by an optional unit keyword, then the rest as the name.
    // Examples:
    //   "2 cups flour"          → qty=2, unit=cups, name=flour
    //   "1/2 tsp salt"          → qty=0.5, unit=tsp, name=salt
    //   "1 1/2 cups sugar"      → qty=1.5, unit=cups, name=sugar
    //   "500g chicken breast"   → qty=500, unit=g, name=chicken breast
    //   "a pinch of salt"       → qty=null, unit=null, name=a pinch of salt
    //   "Salt to taste"         → qty=null, unit=null, name=Salt to taste

    final quantityPattern =
        RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)\s*');
    final unitKeywords = {
      // Volume
      'tsp', 'teaspoon', 'teaspoons',
      'tbsp', 'tablespoon', 'tablespoons',
      'cup', 'cups',
      'ml', 'milliliter', 'milliliters', 'millilitre', 'millilitres',
      'l', 'liter', 'liters', 'litre', 'litres',
      'fl oz', 'fluid ounce', 'fluid ounces',
      'pint', 'pints', 'qt', 'quart', 'quarts', 'gallon', 'gallons',
      // Weight
      'g', 'gram', 'grams',
      'kg', 'kilogram', 'kilograms',
      'oz', 'ounce', 'ounces',
      'lb', 'lbs', 'pound', 'pounds',
      // Count / misc
      'clove', 'cloves', 'slice', 'slices', 'piece', 'pieces',
      'handful', 'pinch', 'bunch', 'can', 'cans', 'package', 'packages',
      'stick', 'sticks', 'sheet', 'sheets', 'sprig', 'sprigs',
      'dash', 'drop', 'drops',
    };

    var remaining = raw;
    double? quantity;
    String? unit;

    // Try to extract a leading quantity
    final qMatch = quantityPattern.firstMatch(remaining);
    if (qMatch != null) {
      quantity = _parseFraction(qMatch.group(1)!);
      remaining = remaining.substring(qMatch.end);
    }

    // Try to extract a leading unit (only when a quantity was found)
    if (quantity != null && remaining.isNotEmpty) {
      // Sort longer units first to avoid matching "l" inside "lb"
      final sortedUnits = unitKeywords.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final u in sortedUnits) {
        // Unit must be followed by whitespace or end-of-string
        final unitRegex = RegExp(
          '^${RegExp.escape(u)}(?=\\s|\$)',
          caseSensitive: false,
        );
        if (unitRegex.hasMatch(remaining)) {
          unit = remaining.substring(0, u.length);
          remaining = remaining.substring(u.length).trim();
          // Strip a leading "of" ("1 cup of flour" → "flour")
          remaining = remaining.replaceFirst(
            RegExp(r'^of\s+', caseSensitive: false),
            '',
          );
          break;
        }
      }
    }

    return _ParsedIngredient(
      quantity: quantity,
      unit: unit,
      name: remaining.trim().isEmpty ? raw : remaining.trim(),
    );
  }

  /// Converts a fraction string like "1/2", "1 1/2", or "2" to a double.
  double _parseFraction(String s) {
    s = s.trim();
    // Mixed number: "1 1/2"
    final mixedMatch = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
    if (mixedMatch != null) {
      return int.parse(mixedMatch.group(1)!) +
          int.parse(mixedMatch.group(2)!) /
              int.parse(mixedMatch.group(3)!);
    }
    // Simple fraction: "3/4"
    final fractionMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (fractionMatch != null) {
      return int.parse(fractionMatch.group(1)!) /
          int.parse(fractionMatch.group(2)!);
    }
    // Plain number
    return double.tryParse(s) ?? 1.0;
  }

  // ---------------------------------------------------------------------------
  // Meta-tag / microdata fallback
  // ---------------------------------------------------------------------------

  /// Last-resort extraction from common meta tags (og:title, og:description,
  /// og:image) when no JSON-LD recipe was found.
  ///
  /// Returns null if the page doesn't even have an og:title, since we can't
  /// build a useful recipe stub without at least a name.
  RecipeEntity? _extractFromMetaTags(
    String html,
    String url,
    String profileId,
  ) {
    String? extractMeta(String property) {
      const q = "[\"']"; // character class matching " or '
      final escaped = RegExp.escape(property);
      // Match both name= and property= variants
      final regex = RegExp(
        '<meta[^>]+(?:property|name)=$q$escaped$q[^>]+content=$q([^"\']+)$q',
        caseSensitive: false,
      );
      final m = regex.firstMatch(html);
      if (m != null) return m.group(1)?.trim();

      // Also try content= before property=
      final regex2 = RegExp(
        '<meta[^>]+content=$q([^"\']+)$q[^>]+(?:property|name)=$q$escaped$q',
        caseSensitive: false,
      );
      return regex2.firstMatch(html)?.group(1)?.trim();
    }

    final title = extractMeta('og:title') ??
        extractMeta('twitter:title') ??
        _extractHtmlTitle(html);

    if (title == null || title.isEmpty) return null;

    final description =
        extractMeta('og:description') ?? extractMeta('twitter:description');
    final imageUrl =
        extractMeta('og:image') ?? extractMeta('twitter:image');

    return RecipeEntity(
      id: '',
      profileId: profileId,
      title: title,
      description: description,
      servings: 1,
      prepTimeMin: null,
      cookTimeMin: null,
      sourceType: 'url',
      sourceUrl: url,
      nutritionScore: null,
      tags: [],
      imageUrl: imageUrl,
      ingredients: [],
      steps: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Extracts the text content of <title> from the raw HTML.
  String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim();
  }
}

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

class _ParsedIngredient {
  const _ParsedIngredient({
    required this.quantity,
    required this.unit,
    required this.name,
  });

  final double? quantity;
  final String? unit;
  final String name;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Riverpod provider for [HtmlRecipeExtractor].
final htmlRecipeExtractorProvider = Provider<HtmlRecipeExtractor>((ref) {
  return HtmlRecipeExtractor();
});
