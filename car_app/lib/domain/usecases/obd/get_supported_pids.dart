import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import '../../repositories/obd_repository.dart';

class GetSupportedPids {
  final OBDRepository repository;

  GetSupportedPids(this.repository);

  Future<Either<Failure, List<String>>> call() async {
    try {
      final pids = await repository.getSupportedPids();
      return Either.right(pids);
    } catch (e) {
      return Either.left(OBDFailure('Error al obtener PIDs soportados: ${e.toString()}'));
    }
  }
}