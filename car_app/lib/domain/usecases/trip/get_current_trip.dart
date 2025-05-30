import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class GetCurrentTrip {
  final TripRepository repository;

  GetCurrentTrip(this.repository);

  Future<Either<Failure, Trip?>> call() async {
    try {
      final trip = await repository.getCurrentTrip();
      return Either.right(trip);
    } catch (e) {
      return Either.left(TripFailure('Error al obtener el viaje actual: ${e.toString()}'));
    }
  }
} 
