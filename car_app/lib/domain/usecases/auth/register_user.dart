import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
// import 'package:car_app/domain/entities/user.dart'; // Ya no se devuelve User
import 'package:car_app/domain/repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository repository;

  RegisterUser(this.repository);

  Future<Either<Failure, String>> call( // Cambiado User por String
    String username, 
    String email, 
    String password,
  ) async {
    try {
      final token = await repository.register(username, email, password);
      return Either.right(token);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 