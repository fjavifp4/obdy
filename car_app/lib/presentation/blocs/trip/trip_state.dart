import 'package:equatable/equatable.dart';
import '../../../domain/entities/trip.dart';

enum TripStatus {
  initial,
  loading,
  ready,
  active,
  error,
}

class TripState extends Equatable {
  final TripStatus status;
  final Trip? currentTrip;
  final Trip? lastCompletedTrip;
  final String? error;

  const TripState({
    required this.status,
    this.currentTrip,
    this.lastCompletedTrip,
    this.error,
  });

  const TripState.initial()
      : status = TripStatus.initial,
        currentTrip = null,
        lastCompletedTrip = null,
        error = null;

  TripState copyWith({
    TripStatus? status,
    Trip? currentTrip,
    Trip? lastCompletedTrip,
    String? error,
  }) {
    return TripState(
      status: status ?? this.status,
      currentTrip: currentTrip ?? this.currentTrip,
      lastCompletedTrip: lastCompletedTrip ?? this.lastCompletedTrip,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, currentTrip, lastCompletedTrip, error];
} 