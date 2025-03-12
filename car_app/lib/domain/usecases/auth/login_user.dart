import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/user.dart';
import 'package:car_app/domain/repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repository;

  LoginUser(this.repository);

  Future<Either<Failure, User>> call(String email, String password) async {
    try {
      final user = await repository.login(email, password);
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 