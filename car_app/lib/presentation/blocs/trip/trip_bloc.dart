import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:car_app/domain/entities/trip.dart';
import 'package:car_app/domain/usecases/usecases.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final InitializeTrip initializeTrip;
  final StartTrip startTrip;
  final EndTrip endTrip;
  final UpdateTripDistance updateTripDistance;
  final GetCurrentTrip getCurrentTrip;
  final UpdateMaintenanceRecordDistance updateMaintenanceRecordDistance;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  GpsPoint? _lastPosition;
  
  TripBloc({
    required this.initializeTrip,
    required this.startTrip,
    required this.endTrip,
    required this.updateTripDistance,
    required this.getCurrentTrip,
    required this.updateMaintenanceRecordDistance,
  }) : super(const TripState.initial()) {
    on<InitializeTripSystem>(_onInitializeTripSystem);
    on<StartTripEvent>(_onStartTrip);
    on<EndTripEvent>(_onEndTrip);
    on<UpdateTripDistanceEvent>(_onUpdateTripDistance);
    on<GetCurrentTripEvent>(_onGetCurrentTrip);
    on<TripLocationUpdated>(_onLocationUpdated);
    on<AutomaticTripDetection>(_onAutomaticTripDetection);
  }
  
  Future<void> _onInitializeTripSystem(
    InitializeTripSystem event, 
    Emitter<TripState> emit
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await initializeTrip();
    
    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        ));
      },
      (_) async {
        // Verificar si hay un viaje activo
        final currentTripResult = await getCurrentTrip();
        
        currentTripResult.fold(
          (failure) {
            emit(state.copyWith(
              status: TripStatus.error,
              error: failure.message,
            ));
          },
          (trip) {
            if (trip != null) {
              emit(state.copyWith(
                status: TripStatus.active,
                currentTrip: trip,
              ));
            } else {
              emit(state.copyWith(status: TripStatus.ready));
            }
          }
        );
      }
    );
  }
  
  Future<void> _onStartTrip(
    StartTripEvent event, 
    Emitter<TripState> emit
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await startTrip(event.vehicleId);
    
    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        ));
      },
      (trip) {
        emit(state.copyWith(
          status: TripStatus.active,
          currentTrip: trip,
        ));
      }
    );
  }
  
  Future<void> _onEndTrip(
    EndTripEvent event, 
    Emitter<TripState> emit
  ) async {
    if (state.currentTrip == null) {
      emit(state.copyWith(
        status: TripStatus.error,
        error: 'No hay un viaje activo para finalizar',
      ));
      return;
    }
    
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await endTrip(event.tripId);
    
    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        ));
      },
      (endedTrip) {
        emit(state.copyWith(
          status: TripStatus.ready,
          currentTrip: null,
          lastCompletedTrip: endedTrip,
        ));
      }
    );
  }
  
  Future<void> _onUpdateTripDistance(
    UpdateTripDistanceEvent event, 
    Emitter<TripState> emit
  ) async {
    if (state.currentTrip == null) {
      emit(state.copyWith(
        status: TripStatus.error,
        error: 'No hay un viaje activo para actualizar',
      ));
      return;
    }
    
    final result = await updateTripDistance(
      tripId: event.tripId,
      distanceInKm: event.distanceInKm,
      newPoint: event.newPoint,
    );
    
    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        ));
      },
      (updatedTrip) {
        emit(state.copyWith(
          currentTrip: updatedTrip,
        ));
      }
    );
  }
  
  Future<void> _onGetCurrentTrip(
    GetCurrentTripEvent event, 
    Emitter<TripState> emit
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await getCurrentTrip();
    
    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        ));
      },
      (trip) {
        if (trip != null) {
          emit(state.copyWith(
            status: TripStatus.active,
            currentTrip: trip,
          ));
        } else {
          emit(state.copyWith(
            status: TripStatus.ready,
            currentTrip: null,
          ));
        }
      }
    );
  }
  
  void _onLocationUpdated(
    TripLocationUpdated event, 
    Emitter<TripState> emit
  ) {
    if (state.currentTrip == null || !state.currentTrip!.isActive) {
      return;
    }
    
    final newPoint = GpsPoint(
      latitude: event.latitude,
      longitude: event.longitude,
      timestamp: event.timestamp,
    );
    
    // Calcular distancia si hay una posición anterior
    if (_lastPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
      
      final distanceInKm = distanceInMeters / 1000;
      
      // Solo actualizar si la distancia es significativa (más de 5 metros)
      if (distanceInMeters > 5) {
        add(UpdateTripDistanceEvent(
          tripId: state.currentTrip!.id,
          distanceInKm: distanceInKm,
          newPoint: newPoint,
        ));
      }
    }
    
    _lastPosition = newPoint;
  }
  
  void _onAutomaticTripDetection(
    AutomaticTripDetection event, 
    Emitter<TripState> emit
  ) {
    if (event.isOBDConnected && event.activeVehicleId != null) {
      if (state.status != TripStatus.active) {
        // Iniciar viaje automáticamente
        add(StartTripEvent(event.activeVehicleId!));
      }
    } else if (!event.isOBDConnected && state.currentTrip != null) {
      // Finalizar viaje automáticamente
      add(EndTripEvent(state.currentTrip!.id));
    }
  }
  
  @override
  Future<void> close() async {
    _positionStreamSubscription?.cancel();
    return super.close();
  }
} 