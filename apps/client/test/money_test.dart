import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/main.dart';

void main() {
  test('USD amounts are parsed using integer cents', () {
    expect(parseMinor('1,234.56'), 123456);
    expect(parseMinor('1'), 100);
    expect(parseMinor('0.09'), 9);
    expect(parseMinor('-0.50', allowNegative: true), -50);
    expect(parseMinor('-100.07', allowNegative: true), -10007);
    expect(() => parseMinor('0.001'), throwsFormatException);
    expect(() => parseMinor('-2.00'), throwsFormatException);
  });
  test('Currency formatter preserves sign and exact cents', () {
    expect(money(125), '\$1.25');
    expect(money(-5020), '-\$50.20');
    expect(money(100000), '\$1,000.00');
  });
}
