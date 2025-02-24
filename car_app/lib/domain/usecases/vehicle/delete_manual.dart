import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
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