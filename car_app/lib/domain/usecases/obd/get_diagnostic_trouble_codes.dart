import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../../domain/repositories/obd_repository.dart';

class GetDiagnosticTroubleCodes {
  final OBDRepository repository;

  GetDiagnosticTroubleCodes(this.repository);

  Future<Either<Failure, List<String>>> call() async {
    try {
      final codes = await repository.getDiagnosticTroubleCodes();
      return Either.right(codes);
    } catch (e) {
      return Either.left(OBDFailure('Error al obtener códigos DTC: ${e.toString()}'));
    }
  }
}
