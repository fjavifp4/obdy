import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/entities/vehicle.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

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