class AisleMapper {
  AisleMapper._();

  static const Map<String, List<String>> _aisleKeywords = {
    'Produce': [
      'lettuce', 'tomato', 'onion', 'garlic', 'pepper', 'carrot', 'celery',
      'potato', 'cucumber', 'avocado', 'lemon', 'lime', 'apple', 'banana',
      'berry', 'spinach', 'kale', 'broccoli', 'mushroom', 'herb', 'basil',
      'cilantro', 'parsley', 'mint', 'ginger', 'zucchini', 'squash', 'corn',
      'bean sprout', 'cabbage', 'salad',
    ],
    'Dairy': [
      'milk', 'cheese', 'yogurt', 'butter', 'cream', 'sour cream', 'egg',
      'cottage', 'ricotta', 'mozzarella', 'cheddar', 'parmesan',
    ],
    'Meat & Seafood': [
      'chicken', 'beef', 'pork', 'turkey', 'lamb', 'fish', 'salmon', 'shrimp',
      'tuna', 'sausage', 'bacon', 'ham', 'steak', 'ground meat', 'seafood',
      'crab', 'lobster', 'tilapia', 'cod',
    ],
    'Bakery': [
      'bread', 'tortilla', 'pita', 'roll', 'bun', 'bagel', 'croissant',
      'muffin', 'cake', 'pastry', 'naan', 'flatbread',
    ],
    'Frozen': [
      'frozen', 'ice cream', 'waffle',
    ],
    'Canned Goods': [
      'canned', 'tomato sauce', 'tomato paste', 'broth', 'stock', 'soup',
      'coconut milk', 'diced tomato',
    ],
    'Dry Goods': [
      'pasta', 'rice', 'flour', 'sugar', 'oat', 'cereal', 'quinoa',
      'couscous', 'lentil', 'noodle', 'breadcrumb', 'cornstarch', 'baking',
    ],
    'Oils & Sauces': [
      'oil', 'olive oil', 'vinegar', 'soy sauce', 'hot sauce', 'ketchup',
      'mustard', 'mayo', 'salad dressing', 'sriracha', 'teriyaki',
      'worcestershire', 'sesame oil',
    ],
    'Spices & Seasonings': [
      'salt', 'pepper', 'cumin', 'paprika', 'oregano', 'thyme', 'cinnamon',
      'nutmeg', 'chili powder', 'turmeric', 'coriander', 'bay leaf',
      'rosemary', 'sage', 'vanilla',
    ],
    'Beverages': [
      'water', 'juice', 'soda', 'coffee', 'tea', 'wine', 'beer',
    ],
  };

  static const Map<String, int> _aisleSortOrder = {
    'Produce': 0,
    'Bakery': 1,
    'Dairy': 2,
    'Meat & Seafood': 3,
    'Frozen': 4,
    'Canned Goods': 5,
    'Dry Goods': 6,
    'Oils & Sauces': 7,
    'Spices & Seasonings': 8,
    'Beverages': 9,
    'Other': 10,
  };

  static String getAisle(String ingredientName) {
    final lower = ingredientName.toLowerCase();
    for (final entry in _aisleKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'Other';
  }

  static int getAisleSortOrder(String aisle) {
    return _aisleSortOrder[aisle] ?? 10;
  }
}
