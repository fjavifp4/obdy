import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/maintenance_record.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class UpdateMaintenanceRecord {
  final VehicleRepository repository;

  UpdateMaintenanceRecord(this.repository);

  Future<Either<Failure, MaintenanceRecord>> call(
    String vehicleId,
    Map<String, dynamic> recordData,
  ) async {
    try {
      final record = await repository.updateMaintenanceRecord(vehicleId, recordData);
      return Either.right(record);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
