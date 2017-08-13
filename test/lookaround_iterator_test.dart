/// This file tests all of the following combinations:
///   * lookbehind in range 0..4
///   * lookahead in range 0..4
///   * underlying iterable is
///     * empty
///     * 1..2 elements smaller than the lookaround buffer
///     * as large as the lookaround buffer
///     * 1..2 elements larger than the lookaround buffer

import 'dart:math';
import 'package:test/test.dart';
import 'package:lookaround_iterator/lookaround_iterator.dart';

int zero(int n) => 0;
int nextSmaller(int n) => n - 1;
int twoSmaller(int n) => n - 2;
int same(int n) => n;
int nextBigger(int n) => n + 1;
int twoBigger(int n) => n + 2;

const List<int Function(int)> relativeNumbers = const [
  zero,
  nextSmaller,
  twoSmaller,
  same,
  nextBigger,
  twoBigger
];

/// Stores the characteristics of one test case combination.
class Combination {
  final int lookbehind;
  final int lookahead;
  int get bufferSize => lookbehind + 1 + lookahead;

  /// This list is used as the underlying iterable for this test case.
  final List<int> list;

  Combination(
      this.lookbehind, this.lookahead, int Function(int) relativeIterableSize)
      : list = new List.generate(
            relativeIterableSize(lookbehind + 1 + lookahead),
            (n) => pow(n + 1, 2));

  /// Returns the expected buffer (in the same format as [viewBuffer]) after
  /// _n_ steps, where step `0` means: the iterator is initialized and points
  /// to the first iterable element.
  List bufferAfterNSteps(int steps) {
    assert(steps >= 0);
    steps = min(steps, list.length);

    final buffer = new List(bufferSize);
    for (int i = 0; i < buffer.length; i++) {
      try {
        buffer[i] = list[i - lookbehind + steps];
      } on RangeError {}
    }
    return buffer;
  }

  String toString() =>
      '$lookbehind lookbehind, $lookahead lookahead over $list';
}

/// Returns a list that represents the buffer of `it`.
List viewBuffer(LookaroundIterator it) => new List.generate(
    it.lookbehind + 1 + it.lookahead, (n) => it[-it.lookbehind + n]);

void main() {
  group('LookaroundIterator: constructor', () {
    test('sets correct lookbehind/lookahead values', () {
      final it =
          new LookaroundIterator([].iterator, lookbehind: 2, lookahead: 3);
      expect(it.lookbehind, 2);
      expect(it.lookahead, 3);
    });

    test('throws on negative lookahead/lookbehind', () {
      expect(() => new LookaroundIterator([].iterator, lookbehind: -1),
          throwsArgumentError);
      expect(() => new LookaroundIterator([].iterator, lookahead: -1),
          throwsArgumentError);
    });
  });

  for (var lookbehind = 0; lookbehind <= 4; lookbehind++) {
    for (var lookahead = 0; lookahead <= 4; lookahead++) {
      for (final relativeNumber in relativeNumbers) {
        if (relativeNumber != zero &&
            relativeNumber(lookbehind + 1 + lookahead) < 1) continue;

        final c = new Combination(lookbehind, lookahead, relativeNumber);
        test('LookaroundIterator: $c', () {
          final it = new LookaroundIterator(c.list.iterator,
              lookbehind: c.lookbehind, lookahead: c.lookahead);

          expect(viewBuffer(it), new List(c.bufferSize),
              reason: 'should be uninitialized (all elements == `null`)');

          for (var i = 0; i < c.list.length; i++) {
            expect(it.moveNext(), isTrue,
                reason: 'iterator (${viewBuffer(it)}) should not be exhausted');
            expect(viewBuffer(it), c.bufferAfterNSteps(i));
          }

          expect(it.moveNext(), isFalse,
              reason: 'iterator (${viewBuffer(it)}) should be exhausted');
          expect(viewBuffer(it), c.bufferAfterNSteps(c.list.length));
          expect(it.moveNext(), isFalse,
              reason: 'iterator (${viewBuffer(it)}) should still be exhausted');
          expect(viewBuffer(it), c.bufferAfterNSteps(c.list.length),
              reason: 'iterator should not change after being exhausted');
        });
      }
    }
  }
}
