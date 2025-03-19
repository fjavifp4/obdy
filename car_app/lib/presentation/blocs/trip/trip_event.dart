// lib/presentation/blocs/trip/trip_event.dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/trip.dart';

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

class InitializeTripSystem extends TripEvent {}

class StartTripEvent extends TripEvent {
  final String vehicleId;
  
  const StartTripEvent(this.vehicleId);
  
  @override
  List<Object> get props => [vehicleId];
}

class EndTripEvent extends TripEvent {
  final String tripId;
  
  const EndTripEvent(this.tripId);
  
  @override
  List<Object> get props => [tripId];
}

class UpdateTripDistanceEvent extends TripEvent {
  final String tripId;
  final double distanceInKm;
  final GpsPoint newPoint;
  
  const UpdateTripDistanceEvent({
    required this.tripId,
    required this.distanceInKm,
    required this.newPoint,
  });
  
  @override
  List<Object> get props => [tripId, distanceInKm, newPoint];
}

class GetCurrentTripEvent extends TripEvent {}

class TripLocationUpdated extends TripEvent {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  
  const TripLocationUpdated({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
  
  @override
  List<Object> get props => [latitude, longitude, timestamp];
}

class AutomaticTripDetection extends TripEvent {
  final bool isOBDConnected;
  final String? activeVehicleId;
  
  const AutomaticTripDetection({
    required this.isOBDConnected,
    this.activeVehicleId,
  });
  
  @override
  List<Object?> get props => [isOBDConnected, activeVehicleId];
}

class GetVehicleStatsEvent extends TripEvent {
  final String vehicleId;

  const GetVehicleStatsEvent({required this.vehicleId});

  @override
  List<Object?> get props => [vehicleId];
} 