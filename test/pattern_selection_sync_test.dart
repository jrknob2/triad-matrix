import 'package:drumcabulary/features/library/pattern_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pattern token spans map source ranges to semantic note events', () {
    final List<TextRange> ranges = patternEventTextRangesForTesting(
      '[S] [HH K] [S:(L)] [T1:R]',
    );

    expect(
      ranges.map((TextRange range) => <int>[range.start, range.end]).toList(),
      <List<int>>[
        <int>[0, 3],
        <int>[4, 10],
        <int>[11, 18],
        <int>[19, 25],
      ],
    );
  });

  test('pattern token spans keep bracketed ghost overrides together', () {
    final List<TextRange> ranges = patternEventTextRangesForTesting(
      '[T2:(R)] [T1:(L)]',
    );

    expect(
      ranges.map((TextRange range) => <int>[range.start, range.end]).toList(),
      <List<int>>[
        <int>[0, 8],
        <int>[9, 17],
      ],
    );
  });
}
