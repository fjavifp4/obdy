import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class UploadManual {
  final VehicleRepository repository;

  UploadManual(this.repository);

  Future<Either<Failure, void>> call(
    String vehicleId,
    List<int> fileBytes,
    String filename,
  ) async {
    try {
      await repository.uploadManual(vehicleId, fileBytes, filename);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
