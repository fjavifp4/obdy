import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import '../../entities/trip.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/vehicle_repository.dart';

class UserStatistics {
  final int totalVehicles;
  final int totalTrips;
  final double totalDistance;
  final double totalDrivingTime; // en horas
  final double totalFuelConsumption;
  final double averageDailyDistance;
  final double averageSpeed;
  final List<Trip> recentTrips;
  final List<Trip> allTrips;

  UserStatistics({
    required this.totalVehicles,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalDrivingTime,
    required this.totalFuelConsumption,
    required this.averageDailyDistance,
    required this.averageSpeed,
    required this.recentTrips,
    required this.allTrips,
  });
}

class GetUserStatistics {
  final TripRepository tripRepository;
  final VehicleRepository vehicleRepository;

  GetUserStatistics(this.tripRepository, this.vehicleRepository);

  Future<Either<Failure, UserStatistics>> call() async {
    try {
      // Obtener todos los vehículos del usuario
      final vehicles = await vehicleRepository.getVehicles();
      final totalVehicles = vehicles.length;

      // Lista para almacenar todos los viajes de todos los vehículos
      List<Trip> allTrips = [];

      // Iterar sobre cada vehículo para obtener sus viajes
      for (final vehicle in vehicles) {
        final tripsForVehicle = await tripRepository.getTripsForVehicle(vehicleId: vehicle.id);
        allTrips.addAll(tripsForVehicle);
      }
      
      final totalTrips = allTrips.length;

      // Calcular distancia total
      final totalDistance = allTrips.fold(0.0, (sum, trip) => sum + trip.distanceInKm);

      // Calcular tiempo total de conducción (en horas)
      final totalDrivingSeconds = allTrips.fold(0, (sum, trip) => sum + trip.durationSeconds);
      final totalDrivingTime = totalDrivingSeconds / 3600; // convertir a horas

      // Calcular consumo total de combustible
      final totalFuelConsumption = allTrips.fold(0.0, (sum, trip) => sum + trip.fuelConsumptionLiters);

      // Calcular distancia media diaria
      double averageDailyDistance = 0.0;
      if (allTrips.isNotEmpty) {
        final oldestTripDate = allTrips.map((trip) => trip.startTime).reduce((min, date) => date.isBefore(min) ? date : min);
        final daysSinceFirstTrip = DateTime.now().difference(oldestTripDate).inDays;
        if (daysSinceFirstTrip > 0) {
          averageDailyDistance = totalDistance / daysSinceFirstTrip;
        } else {
          averageDailyDistance = totalDistance;
        }
      }

      // Calcular velocidad media
      double averageSpeed = 0.0;
      if (totalDrivingTime > 0) {
        averageSpeed = totalDistance / totalDrivingTime;
      } else {
        // Utilizar el promedio de velocidades medias de cada viaje si está disponible
        if (allTrips.isNotEmpty) {
          averageSpeed = allTrips.fold(0.0, (sum, trip) => sum + trip.averageSpeedKmh) / allTrips.length;
        }
      }

      // Obtener los 5 viajes más recientes
      List<Trip> recentTrips = [];
      if (allTrips.isNotEmpty) {
        recentTrips = [...allTrips]..sort((a, b) => b.startTime.compareTo(a.startTime));
        if (recentTrips.length > 5) {
          recentTrips = recentTrips.sublist(0, 5);
        }
      }

      return Either.right(UserStatistics(
        totalVehicles: totalVehicles,
        totalTrips: totalTrips,
        totalDistance: totalDistance,
        totalDrivingTime: totalDrivingTime,
        totalFuelConsumption: totalFuelConsumption,
        averageDailyDistance: averageDailyDistance,
        averageSpeed: averageSpeed,
        recentTrips: recentTrips,
        allTrips: allTrips,
      ));
    } catch (e) {
      return Either.left(TripFailure('Error al obtener estadísticas: ${e.toString()}'));
    }
  }
} 
