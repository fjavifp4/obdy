import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';

class DownloadManual {
  final VehicleRepository repository;

  DownloadManual(this.repository);

  Future<Either<Failure, List<int>>> call(String vehicleId) async {
    try {
      final fileBytes = await repository.downloadManual(vehicleId);
      return Either.right(fileBytes);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
