import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/vehicle.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class AddVehicle {
  final VehicleRepository repository;

  AddVehicle(this.repository);

  Future<Either<Failure, Vehicle>> call(Map<String, dynamic> vehicleData) async {
    try {
      final vehicle = await repository.addVehicle(vehicleData);
      return Either.right(vehicle);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
