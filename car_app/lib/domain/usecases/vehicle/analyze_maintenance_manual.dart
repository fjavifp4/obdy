import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../repositories/vehicle_repository.dart';

class AnalyzeMaintenanceManual {
  final VehicleRepository repository;

  AnalyzeMaintenanceManual(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String vehicleId) async {
    try {
      final recommendations = await repository.analyzeMaintenanceManual(vehicleId);
      return Either.right(recommendations);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 
