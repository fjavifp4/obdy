import 'package:equatable/equatable.dart';
import 'package:obdy/domain/entities/trip.dart';
import 'package:obdy/domain/usecases/trip/get_vehicle_stats.dart';

enum TripStatus {
  initial,
  loading,
  loaded,
  ready,
  active,
  error,
}

class TripState extends Equatable {
  final TripStatus status;
  final Trip? currentTrip;
  final Trip? lastCompletedTrip;
  final String? error;
  final bool locationEnabled;
  final bool recording;
  final bool isOBDConnected;
  final VehicleStats? vehicleStats;

  const TripState({
    required this.status,
    this.currentTrip,
    this.lastCompletedTrip,
    this.error,
    required this.locationEnabled,
    required this.recording,
    required this.isOBDConnected,
    this.vehicleStats,
  });

  const TripState.initial()
      : status = TripStatus.initial,
        currentTrip = null,
        lastCompletedTrip = null,
        error = null,
        locationEnabled = false,
        recording = false,
        isOBDConnected = false,
        vehicleStats = null;

  TripState copyWith({
    TripStatus? status,
    Trip? currentTrip,
    Trip? lastCompletedTrip,
    String? error,
    bool? locationEnabled,
    bool? recording,
    bool? isOBDConnected,
    VehicleStats? vehicleStats,
  }) {
    return TripState(
      status: status ?? this.status,
      currentTrip: currentTrip ?? this.currentTrip,
      lastCompletedTrip: lastCompletedTrip ?? this.lastCompletedTrip,
      error: error,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      recording: recording ?? this.recording,
      isOBDConnected: isOBDConnected ?? this.isOBDConnected,
      vehicleStats: vehicleStats ?? this.vehicleStats,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentTrip,
        lastCompletedTrip,
        error,
        locationEnabled,
        recording,
        isOBDConnected,
        vehicleStats,
      ];
} 
