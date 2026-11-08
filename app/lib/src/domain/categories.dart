/// Spending categories, matched by keywords in the merchant name.
///
/// First match wins, so specific words (grabfood) sit above general ones (grab).
/// When something lands in "Other", add its merchant name here.
library;

const List<(String, List<String>)> categoryRules = [
  (
    'Food & Drinks',
    [
      'grabfood', 'foodpanda', 'shopeefood', 'kantin', 'canteen', 'restaurant', 'restoran', 'cafe', 'kopitiam', //
      'mamak', 'warung', 'gerai', 'medan selera', 'nasi', //
      'mcdonald', 'kfc', 'starbucks', 'zus', 'tealive', 'subway', 'domino', 'pizza', 'bakery', 'texas chicken',
    ],
  ),
  (
    'Groceries',
    [
      '99 speedmart', 'mydin', 'lotus', 'aeon', 'jaya grocer', 'giant', 'econsave', 'village grocer', //
      '7-eleven', '7 eleven', 'family mart', 'familymart', 'kk mart',
    ],
  ),
  (
    'Transport',
    [
      'grab', 'petronas', 'shell', 'petron', 'caltex', 'bhpetrol', 'touch n go', 'parking', 'rapid', 'mrt', //
      'lrt', 'ktm', 'airasia', 'toll',
    ],
  ),
  (
    'Shopping',
    ['shopee', 'lazada', 'tiktok shop', 'uniqlo', 'ikea', 'mr diy', 'mr. diy', 'decathlon', 'watsons', 'guardian'],
  ),
  (
    'Bills',
    [
      'tnb', 'tenaga', 'unifi', 'maxis', 'celcom', 'u mobile', 'yes 4g', 'time dotcom', 'astro', 'indah water', //
      'air selangor',
    ],
  ),
  ('Entertainment', ['netflix', 'spotify', 'youtube', 'disney', 'gsc', 'tgv', 'mbo', 'steam', 'playstation', 'roblox']),
];

/// Picks a category for one transaction. Money in is always "Money in". Otherwise
/// the first keyword match wins, then Wise's own merchant category, then the
/// transaction type, then "Other".
String categorize({required String name, required bool moneyIn, String wiseCategory = '', String detailType = ''}) {
  if (moneyIn) return 'Money in';
  final text = name.toLowerCase();
  for (final (category, words) in categoryRules) {
    if (words.any(text.contains)) return category;
  }
  if (wiseCategory.isNotEmpty) return wiseCategory;
  return switch (detailType) {
    'TRANSFER' => 'Transfers',
    'CONVERSION' => 'Currency exchange',
    _ => 'Other',
  };
}
