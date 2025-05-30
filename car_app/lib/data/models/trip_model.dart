import 'package:obdy/domain/entities/trip.dart';
import 'gps_point_model.dart';

class TripModel {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceInKm;
  final String vehicleId;
  final bool isActive;
  final List<GpsPointModel> gpsPoints;
  final double fuelConsumptionLiters;
  final double averageSpeedKmh;
  final int durationSeconds;

  const TripModel({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.distanceInKm,
    required this.vehicleId,
    required this.isActive,
    required this.gpsPoints,
    this.fuelConsumptionLiters = 0.0,
    this.averageSpeedKmh = 0.0,
    this.durationSeconds = 0,
  });

  // Desde JSON
  factory TripModel.fromJson(Map<String, dynamic> json) {
    List<GpsPointModel> points = [];
    if (json['gps_points'] != null) {
      points = (json['gps_points'] as List)
          .map((point) => GpsPointModel.fromJson(point))
          .toList();
    }

    return TripModel(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      distanceInKm: json['distance_in_km'].toDouble(),
      isActive: json['is_active'],
      gpsPoints: points,
      fuelConsumptionLiters: json['fuel_consumption_liters']?.toDouble() ?? 0.0,
      averageSpeedKmh: json['average_speed_kmh']?.toDouble() ?? 0.0,
      durationSeconds: json['duration_seconds'] ?? 0,
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'distance_in_km': distanceInKm,
      'is_active': isActive,
      'gps_points': gpsPoints.map((point) => point.toJson()).toList(),
      'fuel_consumption_liters': fuelConsumptionLiters,
      'average_speed_kmh': averageSpeedKmh,
      'duration_seconds': durationSeconds,
    };
  }

  // Convertir a entidad de dominio
  Trip toEntity() {
    return Trip(
      id: id,
      startTime: startTime,
      endTime: endTime,
      distanceInKm: distanceInKm,
      vehicleId: vehicleId,
      isActive: isActive,
      gpsPoints: gpsPoints.map((point) => point.toEntity()).toList(),
      fuelConsumptionLiters: fuelConsumptionLiters,
      averageSpeedKmh: averageSpeedKmh,
      durationSeconds: durationSeconds,
    );
  }

  // Desde entidad de dominio
  factory TripModel.fromEntity(Trip entity) {
    return TripModel(
      id: entity.id,
      startTime: entity.startTime,
      endTime: entity.endTime,
      distanceInKm: entity.distanceInKm,
      vehicleId: entity.vehicleId,
      isActive: entity.isActive,
      gpsPoints: entity.gpsPoints.map((point) => GpsPointModel.fromEntity(point)).toList(),
      fuelConsumptionLiters: entity.fuelConsumptionLiters,
      averageSpeedKmh: entity.averageSpeedKmh,
      durationSeconds: entity.durationSeconds,
    );
  }
} 
