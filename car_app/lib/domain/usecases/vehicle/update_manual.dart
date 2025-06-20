import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
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
