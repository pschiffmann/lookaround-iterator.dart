/// Provides a single class, [LookaroundIterator].
library lookaround_iterator;

/// A [LookaroundIterator] cycles through these internal states over successive
/// calls to `moveNext`. (in the order the enum items are declared)
enum _State {
  /// `moveNext` was never called. The buffer is empty.
  uninitialized,

  /// The iterator has been initialized. The last call to `original.moveNext`
  /// returned `true`, so `remainingElements` cannot be determined yet.
  originalNotExhausted,

  /// Calls to `original.moveNext` return `false`. When this state is entered,
  /// `remainingElements` has to be determined, and in subsequent `moveNext`
  /// calls counted down until the iterator is exhausted.
  originalExhausted,

  /// `current` is `null`, and calls to `moveNext` return `false`.
  exhausted
}

/// A lookaround iterator exposes a fixed number of elements in the past and
/// future of the [current] iteration element.
///
/// You must specify the [lookbehind] and [lookahead] bounds on instantiation,
/// and you can access the previous and next items using the subscript operator
/// `[]`. The [current] element is accessible at index `0`, lookbehind elements
/// at negative indexes, and lookahead elements at positive indexes,
/// respectively.
///
///     // `it` is an iterator over a list of the numbers 1..10, currently
///     // pointing at `4`.
///     final it = new LookaroundIterator(
///         new List.generate(10, (n) => n + 1).iterator,
///         lookbehind: 2,
///         lookahead: 3)
///       ..moveNext()
///       ..moveNext()
///       ..moveNext()
///       ..moveNext();
///
///     // Prints _2, 3, 4, 5, 6, 7_.
///     // Notice the negative start index and the inclusive range `<=`.
///     for (int i = -it.lookbehind; i <= it.lookahead; i++) {
///       print(it[i]);
///     }
///
/// Before the first call to [moveNext], the lookahead buffer contains only
/// `null` elements. After the iterator is exhausted ([moveNext] returns
/// `false`), the last elements remain accessible in the lookbehind buffer.
class LookaroundIterator<T> implements Iterator<T> {
  /// Provides the elements that this object iterates over.
  final Iterator<T> _original;

  /// Stores the current, lookbehind and lookahead elements after they have been
  /// extracted from [_original]. Index `0` is the oldest value that will be
  /// shifted out of the lookbehind buffer in the next iteration step.
  final List<T> _buffer;

  /// The index into [_buffer] at which [current] is stored.
  final int _indexOfCurrent;

  /// The current state of this iterator. Used and modified by [moveNext].
  _State _state = _State.uninitialized;

  /// Stores the number of elements in the [current] and lookahead buffer
  /// combined – for example, `1` means the lookahead buffer is empty, but
  /// [current] still contains an item.
  ///
  /// Only used while this is in [_State.originalExhausted] state.
  int _remainingElements;

  /// This iterator knows the next _lookahead_ elements that will follow
  /// [current].
  int get lookahead => _buffer.length - _indexOfCurrent - 1;

  /// This iterator remembers the [current] elements of the last _lookbehind_
  /// steps.
  int get lookbehind => _indexOfCurrent;

  /// Returns the element that was [current] before the last call to
  /// [moveNext], if [lookbehind] >= 1. Else, throws a [RangeError].
  T get previous => this[-1];

  @override
  T get current => this[0];

  /// Returns the element that will be [current] after the next call to
  /// [moveNext], if [lookahead] >= 1. Else, throws a [RangeError].
  T get next => this[1];

  /// Returns an element from this iterator at the specified offset: `0` is the
  /// current element; negative offsets specify _lookbehind_, positive offsets
  /// specify _lookahead_.
  ///
  /// Throws a [RangeError] if the offset is outside the lookbehind/lookahead
  /// range.
  T operator [](int offset) {
    try {
      return _buffer[_indexOfCurrent + offset];
    } on RangeError {
      throw new RangeError.range(offset, lookbehind, lookahead);
    }
  }

  /// Constructs a lookaround iterator that wraps `original` and uses the
  /// specified [lookahead] and [lookbehind] values.
  ///
  /// Throws an [ArgumentError] if `lookahead` or `lookbehind` are negative.
  LookaroundIterator(Iterator<T> original,
      {int lookahead: 0, int lookbehind: 0})
      : _original = original,
        _indexOfCurrent = lookbehind,
        _buffer = new List<T>(lookbehind + 1 + lookahead) {
    if (lookahead < 0)
      throw new ArgumentError.value(
          lookahead, 'lookahead', 'must be non-negative');
    if (lookbehind < 0)
      throw new ArgumentError.value(
          lookbehind, 'lookbehind', 'must be non-negative');
  }

  @override
  bool moveNext() {
    // Shifts [_buffer] one index towards index 0, and fills the highest index
    // with  [_original.current].
    void shift() {
      for (var i = 1; i < _buffer.length; i++) {
        _buffer[i - 1] = _buffer[i];
      }
      _buffer[_buffer.length - 1] = _original.current;
    }

    stateTransition:
    switch (_state) {
      case _State.uninitialized:
        for (var i = _indexOfCurrent; i < _buffer.length; i++) {
          if (!_original.moveNext()) {
            _state = i == _indexOfCurrent
                ? _State.exhausted
                : _State.originalExhausted;
            _remainingElements = i - _indexOfCurrent;
            break stateTransition;
          }
          _buffer[i] = _original.current;
        }
        _state = _State.originalNotExhausted;
        break;
      case _State.originalNotExhausted:
        if (!_original.moveNext()) {
          _state = lookahead == 0 ? _State.exhausted : _State.originalExhausted;
          _remainingElements = lookahead;
        }
        shift();
        break;
      case _State.originalExhausted:
        shift();
        if (--_remainingElements == 0) {
          _state = _State.exhausted;
        }
        break;
      case _State.exhausted:
        break;
    }

    return _state != _State.exhausted;
  }
}
