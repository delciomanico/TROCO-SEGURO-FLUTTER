import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:troco_seguro/utils/formatters.dart';

void main() {
  group('AppFormatters.currency', () {
    test('matches the underlying NumberFormat pattern while decimals are disabled', () {
      expect(AppFormatters.decimalsEnabled, isFalse);
      final expected = NumberFormat('#,##0', 'pt_AO');
      expect(AppFormatters.currency(1000), expected.format(1000));
      expect(AppFormatters.currency(2500000), expected.format(2500000));
    });

    test('formats zero and small values without throwing', () {
      final expected = NumberFormat('#,##0', 'pt_AO');
      expect(AppFormatters.currency(0), expected.format(0));
      expect(AppFormatters.currency(5), expected.format(5));
    });

    test('does not include decimal separators while decimals are disabled', () {
      expect(AppFormatters.currency(1234), isNot(contains(RegExp(r'[.,]\d{2}$'))));
    });
  });
}
