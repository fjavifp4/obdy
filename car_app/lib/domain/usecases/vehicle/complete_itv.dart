import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class CompleteItv {
  final VehicleRepository repository;

  CompleteItv(this.repository);

  Future<Either<Failure, void>> call(String vehicleId) async {
    try {
      await repository.completeItv(vehicleId);
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
} 
