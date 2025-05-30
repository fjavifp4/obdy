import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

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
