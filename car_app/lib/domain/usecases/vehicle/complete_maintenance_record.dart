import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/maintenance_record.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class CompleteMaintenanceRecord {
  final VehicleRepository repository;

  CompleteMaintenanceRecord(this.repository);

  Future<Either<Failure, MaintenanceRecord>> call(
    String vehicleId,
    String maintenanceId,
  ) async {
    try {
      final record = await repository.completeMaintenanceRecord(vehicleId, maintenanceId);
      return Either.right(record);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 