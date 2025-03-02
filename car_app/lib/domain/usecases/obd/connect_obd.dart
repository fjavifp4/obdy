import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import '../../repositories/obd_repository.dart';

class ConnectOBD {
  final OBDRepository repository;

  ConnectOBD(this.repository);

  Future<Either<Failure, bool>> call() async {
    try {
      final result = await repository.connect();
      return Either.right(result);
    } catch (e) {
      return Either.left(OBDFailure('Error al conectar con OBD: ${e.toString()}'));
    }
  }
}