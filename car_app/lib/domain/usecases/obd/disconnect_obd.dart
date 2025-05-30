import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../../domain/repositories/obd_repository.dart';

class DisconnectOBD {
  final OBDRepository repository;

  DisconnectOBD(this.repository);

  Future<Either<Failure, void>> call() async {
    try {
      await repository.disconnect();
      return Either.right(null);
    } catch (e) {
      return Either.left(OBDFailure('Error al desconectar OBD: ${e.toString()}'));
    }
  }
}
