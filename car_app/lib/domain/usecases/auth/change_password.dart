import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/auth_repository.dart';
import 'package:obdy/config/core/either.dart';

class ChangePassword {
  final AuthRepository repository;

  ChangePassword(this.repository);

  Future<Either<Failure, void>> call(String currentPassword, String newPassword) async {
    try {
      await repository.changePassword(currentPassword, newPassword);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
