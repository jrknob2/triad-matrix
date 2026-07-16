import 'package:drumcabulary/features/library/pattern_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pattern token spans map source ranges to semantic note events', () {
    final List<TextRange> ranges = patternEventTextRangesForTesting(
      'R [HH K:R] ^(L) [T1 16:R]',
    );

    expect(
      ranges.map((TextRange range) => <int>[range.start, range.end]).toList(),
      <List<int>>[
        <int>[0, 1],
        <int>[2, 10],
        <int>[11, 15],
        <int>[16, 25],
      ],
    );
  });

  test('pattern token spans keep bracketed ghost overrides together', () {
    final List<TextRange> ranges = patternEventTextRangesForTesting(
      '([T2:R]) [T1:(L)]',
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
