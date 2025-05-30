import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class StartTrip {
  final TripRepository repository;

  StartTrip(this.repository);

  Future<Either<Failure, Trip>> call(String vehicleId) async {
    try {
      final trip = await repository.startTrip(vehicleId: vehicleId);
      return Either.right(trip);
    } catch (e) {
      return Either.left(TripFailure('Error al iniciar el viaje: ${e.toString()}'));
    }
  }
} 
