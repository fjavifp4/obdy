import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import '../../repositories/trip_repository.dart';

class UpdateMaintenanceRecordDistance {
  final TripRepository repository;

  UpdateMaintenanceRecordDistance(this.repository);

  Future<Either<Failure, bool>> call({
    required String vehicleId,
    required String maintenanceRecordId,
    required double additionalDistance,
  }) async {
    try {
      final result = await repository.updateMaintenanceRecordDistance(
        vehicleId: vehicleId,
        maintenanceRecordId: maintenanceRecordId,
        additionalDistance: additionalDistance,
      );
      return Either.right(result);
    } catch (e) {
      return Either.left(TripFailure('Error al actualizar la distancia del registro de mantenimiento: ${e.toString()}'));
    }
  }
} 