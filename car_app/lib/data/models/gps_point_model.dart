import 'package:car_app/domain/entities/trip.dart';

class GpsPointModel {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const GpsPointModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  // Desde JSON
  factory GpsPointModel.fromJson(Map<String, dynamic> json) {
    return GpsPointModel(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Convertir a entidad de dominio
  GpsPoint toEntity() {
    return GpsPoint(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
  }

  // Desde entidad de dominio
  factory GpsPointModel.fromEntity(GpsPoint entity) {
    return GpsPointModel(
      latitude: entity.latitude,
      longitude: entity.longitude,
      timestamp: entity.timestamp,
    );
  }
} 