import '../entities/trip.dart';

abstract class TripRepository {
  Future<void> initialize([String? token]);
  Future<Trip> startTrip({required String vehicleId});
  Future<Trip> endTrip({required String tripId});
  Future<Trip> updateTripDistance({
    required String tripId,
    required double distanceInKm,
    required GpsPoint newPoint,
    List<GpsPoint>? batchPoints,
  });
  Future<List<Trip>> getTripsForVehicle({required String vehicleId});
  Future<List<Trip>> getAllTrips();
  Future<Trip?> getCurrentTrip();
  Future<double> getTotalDistanceForVehicle({required String vehicleId});
  Future<bool> updateMaintenanceRecordDistance({
    required String vehicleId,
    required String maintenanceRecordId,
    required double additionalDistance,
  });
} 