import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import '../../repositories/vehicle_repository.dart';

class UpdateManual {
  final VehicleRepository repository;

  UpdateManual(this.repository);

  Future<Either<Failure, void>> call(String vehicleId, List<int> fileBytes, String filename) async {
    try {
      await repository.updateManual(vehicleId, fileBytes, filename);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 