import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/entities/vehicle.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

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