import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../repositories/trip_repository.dart';

class InitializeTrip {
  final TripRepository repository;

  InitializeTrip(this.repository);

  Future<Either<Failure, void>> call() async {
    try {
      await repository.initialize();
      return Either.right(null);
    } catch (e) {
      return Either.left(TripFailure('Error al inicializar el sistema de viajes: ${e.toString()}'));
    }
  }
} 
