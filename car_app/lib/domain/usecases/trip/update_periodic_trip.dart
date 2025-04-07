import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/trip.dart';
import '../../repositories/trip_repository.dart';

/// Caso de uso para actualizar periódicamente un viaje activo con datos acumulados
/// y un lote de puntos GPS.
class UpdatePeriodicTrip {
  final TripRepository repository;

  UpdatePeriodicTrip(this.repository);

  /// Llama al método del repositorio para actualizar el viaje.
  ///
  /// [tripId]: ID del viaje a actualizar.
  /// [batchPoints]: Lista de nuevos puntos GPS acumulados desde la última actualización.
  /// [totalDistance]: Distancia total acumulada del viaje en km.
  /// [totalFuelConsumed]: Consumo total de combustible acumulado en litros.
  /// [averageSpeed]: Velocidad media calculada del viaje en km/h.
  /// [durationSeconds]: Duración actual total del viaje en segundos.
  Future<Either<Failure, Trip>> call({
    required String tripId,
    required List<GpsPoint> batchPoints,
    required double totalDistance,
    required double totalFuelConsumed,
    required double averageSpeed,
    required int durationSeconds,
  }) async {
    try {
      final trip = await repository.updatePeriodicTrip(
        tripId: tripId,
        batchPoints: batchPoints,
        totalDistance: totalDistance,
        totalFuelConsumed: totalFuelConsumed,
        averageSpeed: averageSpeed,
        durationSeconds: durationSeconds,
      );
      return Either.right(trip);
    } catch (e) {
      // Usar TripFailure para errores específicos de viajes si está definido, si no, ServerFailure
      // Asegúrate de tener definida la clase TripFailure que herede de Failure.
      // return Either.left(TripFailure('Error en actualización periódica: ${e.toString()}'));
      return Either.left(ServerFailure('Error en actualización periódica: ${e.toString()}'));
    }
  }
}
