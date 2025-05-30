import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class UpdateTripDistance {
  final TripRepository repository;

  UpdateTripDistance(this.repository);

  Future<Either<Failure, Trip>> call({
    required String tripId,
    required double distanceInKm,
    required GpsPoint newPoint,
    List<GpsPoint>? batchPoints,
  }) async {
    try {
      final trip = await repository.updateTripDistance(
        tripId: tripId,
        distanceInKm: distanceInKm,
        newPoint: newPoint,
        batchPoints: batchPoints,
      );
      return Either.right(trip);
    } catch (e) {
      return Either.left(TripFailure('Error al actualizar la distancia del viaje: ${e.toString()}'));
    }
  }
} 
