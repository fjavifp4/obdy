import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class DeleteMaintenanceRecord {
  final VehicleRepository repository;

  DeleteMaintenanceRecord(this.repository);

  Future<Either<Failure, void>> call(String vehicleId, String maintenanceId) async {
    try {
      await repository.deleteMaintenanceRecord(vehicleId, maintenanceId);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 