import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class InitializeVehicle {
  final VehicleRepository repository;

  InitializeVehicle(this.repository);

  Future<Either<Failure, void>> call(String token) async {
    try {
      await repository.initialize(token);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 