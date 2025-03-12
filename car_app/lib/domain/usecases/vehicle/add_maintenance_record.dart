import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/maintenance_record.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class AddMaintenanceRecord {
  final VehicleRepository repository;

  AddMaintenanceRecord(this.repository);

  Future<Either<Failure, MaintenanceRecord>> call(
    String vehicleId,
    Map<String, dynamic> recordData,
  ) async {
    try {
      final record = await repository.addMaintenanceRecord(vehicleId, recordData);
      return Either.right(record);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 