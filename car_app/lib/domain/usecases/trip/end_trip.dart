import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class EndTrip {
  final TripRepository repository;

  EndTrip(this.repository);

  Future<Either<Failure, Trip>> call(String tripId) async {
    try {
      final trip = await repository.endTrip(tripId: tripId);
      return Either.right(trip);
    } catch (e) {
      return Either.left(TripFailure('Error al finalizar el viaje: ${e.toString()}'));
    }
  }
} 
