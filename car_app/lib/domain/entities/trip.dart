import 'package:equatable/equatable.dart';

class Trip extends Equatable {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceInKm;
  final String vehicleId;
  final bool isActive;
  final List<GpsPoint> gpsPoints;
  final double fuelConsumptionLiters;
  final double averageSpeedKmh;
  final int durationSeconds;

  const Trip({
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

  Trip copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceInKm,
    String? vehicleId,
    bool? isActive,
    List<GpsPoint>? gpsPoints,
    double? fuelConsumptionLiters,
    double? averageSpeedKmh,
    int? durationSeconds,
  }) {
    return Trip(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceInKm: distanceInKm ?? this.distanceInKm,
      vehicleId: vehicleId ?? this.vehicleId,
      isActive: isActive ?? this.isActive,
      gpsPoints: gpsPoints ?? this.gpsPoints,
      fuelConsumptionLiters: fuelConsumptionLiters ?? this.fuelConsumptionLiters,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        startTime,
        endTime,
        distanceInKm,
        vehicleId,
        isActive,
        gpsPoints,
        fuelConsumptionLiters,
        averageSpeedKmh,
        durationSeconds,
      ];
}

class GpsPoint extends Equatable {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  List<Object> get props => [latitude, longitude, timestamp];
} 