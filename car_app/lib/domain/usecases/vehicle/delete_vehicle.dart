import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class DeleteVehicle {
  final VehicleRepository repository;

  DeleteVehicle(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    try {
      await repository.deleteVehicle(id);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 