import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class UpdateItv {
  final VehicleRepository repository;

  UpdateItv(this.repository);

  Future<Either<Failure, void>> call(String vehicleId, DateTime itvDate) async {
    try {
      await repository.updateItv(vehicleId, itvDate);
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
} 