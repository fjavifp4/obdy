import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

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
