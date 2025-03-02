class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool isRight;

  const Either._(this._left, this._right, this.isRight);

  factory Either.left(L value) => Either._(value, null, false);
  factory Either.right(R value) => Either._(null, value, true);

  T fold<T>(T Function(L) onLeft, T Function(R) onRight) {
    return isRight ? onRight(_right as R) : onLeft(_left as L);
  }

  R getOrElse(R Function(L) onLeft) {
    return isRight ? (_right as R) : onLeft(_left as L);
  }

  bool isLeft() => !isRight;

  L get left => _left as L;
  R get right => _right as R;
} 