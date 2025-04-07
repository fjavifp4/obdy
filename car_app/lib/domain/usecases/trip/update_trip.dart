/*import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class UpdateTrip {
  final TripRepository repository;

  UpdateTrip(this.repository);

  Future<Either<Failure, Trip>> call(String tripId, Map<String, dynamic> data) async {
    try {
      final updatedTrip = await repository.updateTrip(tripId, data);
      return Either.right(updatedTrip);
    } catch (e) {
      return Either.left(ServerFailure('Error al actualizar el viaje: $e'));
    }
  }
}*/