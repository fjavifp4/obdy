import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/repositories/auth_repository.dart';

class LogoutUser {
  final AuthRepository repository;

  LogoutUser(this.repository);

  Future<Either<Failure, void>> call() async {
    try {
      await repository.logout();
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 