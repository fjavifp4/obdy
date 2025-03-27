import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:car_app/domain/entities/trip.dart';
import 'package:car_app/domain/usecases/usecases.dart';
import 'package:car_app/domain/usecases/trip/get_vehicle_stats.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final InitializeTrip initializeTrip;
  final StartTrip startTrip;
  final EndTrip endTrip;
  final UpdateTripDistance updateTripDistance;
  final GetCurrentTrip getCurrentTrip;
  final UpdateMaintenanceRecordDistance updateMaintenanceRecordDistance;
  final GetVehicleStats getVehicleStats;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  GpsPoint? _lastPosition;
  
  TripBloc({
    required this.initializeTrip,
    required this.startTrip,
    required this.endTrip,
    required this.updateTripDistance,
    required this.getCurrentTrip,
    required this.updateMaintenanceRecordDistance,
    required this.getVehicleStats,
  }) : super(const TripState.initial()) {
    on<InitializeTripSystem>(_onInitializeTripSystem);
    on<StartTripEvent>(_onStartTrip);
    on<EndTripEvent>(_onEndTrip);
    on<UpdateTripDistanceEvent>(_onUpdateTripDistance);
    on<GetCurrentTripEvent>(_onGetCurrentTrip);
    on<TripLocationUpdated>(_onLocationUpdated);
    on<AutomaticTripDetection>(_onAutomaticTripDetection);
    on<GetVehicleStatsEvent>(_onGetVehicleStats);
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
        
        if (!emit.isDone) {
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
      }
    );
  }
  
  Future<void> _onStartTrip(
    StartTripEvent event, 
    Emitter<TripState> emit
  ) async {
    print("[TripBloc] Iniciando viaje: vehicleId=${event.vehicleId}, isSimulationMode=${state.isOBDConnected}");
    emit(state.copyWith(status: TripStatus.loading));
    
    // Primero, verificar si hay un viaje activo para evitar errores
    final currentTripResult = await getCurrentTrip();
    
    await currentTripResult.fold(
      (failure) async {
        // Si hay error al verificar, intentamos iniciar el viaje de todas formas
        print("[TripBloc] Error al verificar viaje actual: ${failure.message}");
        
        final result = await startTrip(event.vehicleId);
        
        if (!emit.isDone) {
          result.fold(
            (failure) {
              print("[TripBloc] ERROR al iniciar viaje: ${failure.message}");
              emit(state.copyWith(
                status: TripStatus.error,
                error: failure.message,
              ));
            },
            (trip) {
              print("[TripBloc] Viaje iniciado correctamente: ${trip.id}");
              emit(state.copyWith(
                status: TripStatus.active,
                currentTrip: trip,
                error: null, // Limpiar errores anteriores
              ));
            }
          );
        }
      },
      (existingTrip) async {
        // Si ya hay un viaje activo, lo usamos en lugar de crear uno nuevo
        if (existingTrip != null && existingTrip.isActive) {
          print("[TripBloc] Ya existe un viaje activo (${existingTrip.id}), usando este");
          emit(state.copyWith(
            status: TripStatus.active,
            currentTrip: existingTrip,
            error: null, // Limpiar errores anteriores
          ));
        } else {
          // Si no hay viaje activo, intentamos crear uno nuevo
          final result = await startTrip(event.vehicleId);
          
          if (!emit.isDone) {
            result.fold(
              (failure) {
                print("[TripBloc] ERROR al iniciar viaje: ${failure.message}");
                emit(state.copyWith(
                  status: TripStatus.error,
                  error: failure.message,
                ));
              },
              (trip) {
                print("[TripBloc] Viaje iniciado correctamente: ${trip.id}");
                emit(state.copyWith(
                  status: TripStatus.active,
                  currentTrip: trip,
                  error: null, // Limpiar errores anteriores
                ));
              }
            );
          }
        }
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
    
    if (!emit.isDone) {
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
    
    if (!emit.isDone) {
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
  }
  
  Future<void> _onGetCurrentTrip(
    GetCurrentTripEvent event, 
    Emitter<TripState> emit
  ) async {
    print("[TripBloc] Buscando viaje actual");
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await getCurrentTrip();
    
    if (!emit.isDone) {
      result.fold(
        (failure) {
          print("[TripBloc] Error al obtener viaje actual: ${failure.message}");
          emit(state.copyWith(
            status: TripStatus.error,
            error: failure.message,
          ));
        },
        (trip) {
          if (trip != null) {
            print("[TripBloc] Viaje activo encontrado: ${trip.id}");
            emit(state.copyWith(
              status: TripStatus.active,
              currentTrip: trip,
              error: null, // Limpiar errores anteriores
            ));
          } else {
            print("[TripBloc] No hay viaje activo");
            emit(state.copyWith(
              status: TripStatus.ready,
              currentTrip: null,
              error: null, // Limpiar errores anteriores
            ));
          }
        }
      );
    }
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
  
  Future<void> _onGetVehicleStats(
    GetVehicleStatsEvent event,
    Emitter<TripState> emit,
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await getVehicleStats(event.vehicleId);
    
    if (!emit.isDone) {
      result.fold(
        (failure) => emit(state.copyWith(
          status: TripStatus.error,
          error: failure.message,
        )),
        (stats) => emit(state.copyWith(
          status: TripStatus.loaded,
          vehicleStats: stats,
        )),
      );
    }
  }
  
  @override
  Future<void> close() async {
    _positionStreamSubscription?.cancel();
    return super.close();
  }
} 