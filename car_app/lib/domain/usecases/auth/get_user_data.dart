import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/user.dart';
import 'package:obdy/domain/repositories/auth_repository.dart';

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
