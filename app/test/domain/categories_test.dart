import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/src/domain/categories.dart';

void main() {
  String category(String name) => categorize(name: name, moneyIn: false);

  test('the workplace canteen counts as food', () {
    expect(category('KANTIN PEJABAT'), 'Food & Drinks');
  });

  test('AI and software subscriptions have their own category instead of "Other"', () {
    expect(category('ANTHROPIC'), 'AI & software');
    expect(category('OPENAI *CHATGPT SUBSCR'), 'AI & software');
    expect(category('GITHUB, INC.'), 'AI & software');
    expect(category('APPLE.COM/BILL'), 'AI & software');
  });

  test('streaming stays entertainment', () {
    expect(category('NETFLIX.COM'), 'Entertainment');
  });
}
