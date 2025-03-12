import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

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