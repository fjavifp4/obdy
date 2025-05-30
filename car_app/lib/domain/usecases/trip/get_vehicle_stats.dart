import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';

class VehicleStats {
  final int totalTrips;
  final double totalDistance;
  final double averageTripLength;
  final List<Trip> recentTrips;

  VehicleStats({
    required this.totalTrips,
    required this.totalDistance,
    required this.averageTripLength,
    required this.recentTrips,
  });
}

class GetVehicleStats {
  final TripRepository repository;

  GetVehicleStats(this.repository);

  Future<Either<Failure, VehicleStats>> call(String vehicleId) async {
    try {
      // Obtener todos los viajes del vehículo
      final trips = await repository.getTripsForVehicle(vehicleId: vehicleId);
      
      // Obtener la distancia total del vehículo
      final totalDistance = await repository.getTotalDistanceForVehicle(vehicleId: vehicleId);
      
      // Calcular estadísticas
      final totalTrips = trips.length;
      final averageTripLength = totalTrips > 0 ? totalDistance / totalTrips : 0.0;
      
      // Obtener los últimos 10 viajes para el gráfico
      final recentTrips = trips.length > 10 
          ? trips.sublist(trips.length - 10)
          : trips;
      
      final vehicleStats = VehicleStats(
        totalTrips: totalTrips,
        totalDistance: totalDistance,
        averageTripLength: averageTripLength,
        recentTrips: recentTrips,
      );
      
      return Either.right(vehicleStats);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
} 
