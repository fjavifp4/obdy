import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../repositories/vehicle_repository.dart';

class DeleteManual {
  final VehicleRepository repository;

  DeleteManual(this.repository);

  Future<Either<Failure, void>> call(String vehicleId) async {
    try {
      await repository.deleteManual(vehicleId);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
