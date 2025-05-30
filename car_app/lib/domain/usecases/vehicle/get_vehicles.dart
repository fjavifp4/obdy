import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/vehicle.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class GetVehicles {
  final VehicleRepository repository;

  GetVehicles(this.repository);

  Future<Either<Failure, List<Vehicle>>> call() async {
    try {
      final vehicles = await repository.getVehicles();
      return Either.right(vehicles);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
