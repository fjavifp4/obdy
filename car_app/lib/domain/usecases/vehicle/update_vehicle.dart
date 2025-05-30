import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/vehicle.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class UpdateVehicle {
  final VehicleRepository repository;

  UpdateVehicle(this.repository);

  Future<Either<Failure, Vehicle>> call(String id, Map<String, dynamic> updates) async {
    try {
      final vehicle = await repository.updateVehicle(id, updates);
      return Either.right(vehicle);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
