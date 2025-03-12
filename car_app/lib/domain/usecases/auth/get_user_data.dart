import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/user.dart';
import 'package:car_app/domain/repositories/auth_repository.dart';

class GetUserData {
  final AuthRepository repository;

  GetUserData(this.repository);

  Future<Either<Failure, User>> call() async {
    try {
      final user = await repository.getUserData();
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 