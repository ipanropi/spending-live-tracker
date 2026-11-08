import '../domain/categories.dart';
import '../domain/models.dart';
import 'wise_api.dart';

/// Realistic made-up data, relative to today. Used by tests and for screenshots
/// (`--dart-define=FAKE_DATA=true`); never in a normal build.
class FakeSource implements StatementSource {
  FakeSource({DateTime Function()? clock, this.delay = const Duration(milliseconds: 400)})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration delay;

  @override
  Future<void> verify() => Future<void>.delayed(delay);

  @override
  Future<Statement> fetchStatement() async {
    await Future<void>.delayed(delay);
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final txns = <Txn>[];
    void spend(int daysAgo, int hour, int minute, int cents, String name, [String note = '']) => txns.add(
      Txn(
        date: today.subtract(Duration(days: daysAgo)).add(Duration(hours: hour, minutes: minute)),
        cents: -cents,
        name: name,
        category: categorize(name: name, moneyIn: false, detailType: name == 'Ali Bin Abu' ? 'TRANSFER' : 'CARD'),
        note: note,
      ),
    );

    spend(0, 8, 15, 650, 'KANTIN PEJABAT');
    spend(0, 12, 30, 1250, 'ZUS COFFEE PENANG', 'Card transaction of 12.50 MYR issued by Zus Coffee');
    spend(0, 18, 10, 560, 'KTM BERHAD');
    spend(1, 9, 5, 750, 'KANTIN PEJABAT');
    spend(1, 13, 40, 2150, '99 SPEEDMART 2210');
    spend(1, 19, 15, 3290, 'GRABFOOD');
    spend(2, 7, 50, 560, 'KTM BERHAD');
    spend(2, 10, 20, 9800, 'ANTHROPIC');
    spend(2, 14, 15, 5000, 'Ali Bin Abu', 'Duit makan minggu ni');
    spend(3, 11, 0, 4490, 'SHOPEE MALAYSIA');
    spend(3, 12, 45, 800, 'KANTIN PEJABAT');
    spend(4, 18, 30, 2500, 'GRAB*RIDE');
    spend(5, 10, 30, 990, 'ZUS COFFEE PENANG');
    spend(6, 12, 0, 1800, 'KEDAI RUNCIT AMAN');
    spend(9, 12, 15, 4890, '99 SPEEDMART 1234');
    spend(12, 19, 0, 3000, 'Ali Bin Abu');
    spend(20, 8, 40, 1500, 'GRAB*RIDE');
    spend(33, 20, 0, 5490, 'NETFLIX.COM');
    spend(45, 13, 0, 1500, 'Random Shop');
    txns.add(
      Txn(
        date: today.subtract(const Duration(days: 8)).add(const Duration(hours: 9)),
        cents: 89000,
        name: 'MUHAMMAD IRFAN',
        category: 'Money in',
        note: 'Top-up',
      ),
    );
    txns.sort((a, b) => b.date.compareTo(a.date));
    return Statement(transactions: txns, balanceCents: 178000, fetchedAt: now);
  }

  @override
  void close() {}
}
