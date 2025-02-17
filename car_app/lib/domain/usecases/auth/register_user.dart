import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/entities/user.dart';
import 'package:car_app/domain/repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository repository;

  RegisterUser(this.repository);

  Future<Either<Failure, User>> call(
    String username, 
    String email, 
    String password,
  ) async {
    try {
      final user = await repository.register(username, email, password);
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 