class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool isRight;

  Either._({L? left, R? right, required this.isRight})
      : _left = left,
        _right = right;

  factory Either.left(L value) => Either._(left: value, isRight: false);
  factory Either.right(R value) => Either._(right: value, isRight: true);

  Future<void> fold(
    Future<void> Function(L) onLeft,
    Future<void> Function(R) onRight,
  ) async {
    if (isRight) {
      await onRight(_right as R);
    } else {
      await onLeft(_left as L);
    }
  }

  R getOrElse(R Function() onLeft) {
    if (isRight) {
      return _right as R;
    } else {
      return onLeft();
    }
  }
} 