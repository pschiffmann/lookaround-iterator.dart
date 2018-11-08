Dart lookaround iterator
========================

[![Build Status](https://travis-ci.com/pschiffmann/lookaround-iterator.dart.svg?branch=master)](https://travis-ci.com/pschiffmann/lookaround-iterator.dart)

The `LookaroundIterator` class exposes a fixed number of elements in the past and future of the current iteration element.

```Dart
// `it` is an iterator over a list of the numbers 1..10, currently
// pointing at `4`.
final it = LookaroundIterator(
    List.generate(10, (n) => n + 1).iterator,
    lookbehind: 2,
    lookahead: 3)
  ..moveNext()
  ..moveNext()
  ..moveNext()
  ..moveNext();

// Prints _2, 3, 4, 5, 6, 7_.
// Notice the negative start index and the inclusive range `<=`.
for (int i = -it.lookbehind; i <= it.lookahead; i++) {
  print(it[i]);
}
```
