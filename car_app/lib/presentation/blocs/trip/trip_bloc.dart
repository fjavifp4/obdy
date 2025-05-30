import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obdy/domain/entities/trip.dart';
import 'package:obdy/domain/usecases/trip/start_trip.dart';
import 'package:obdy/domain/usecases/trip/end_trip.dart';
import 'package:obdy/domain/usecases/trip/get_current_trip.dart';
import 'package:obdy/domain/usecases/trip/update_periodic_trip.dart';
import 'package:obdy/domain/usecases/trip/get_vehicle_stats.dart';
import 'package:obdy/domain/usecases/trip/initialize_trip.dart';
import 'trip_event.dart';
import 'trip_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final InitializeTrip _initializeTrip;
  final StartTrip _startTrip;
  final EndTrip _endTrip;
  final GetCurrentTrip _getCurrentTrip;
  final UpdatePeriodicTrip _updatePeriodicTrip;
  final GetVehicleStats _getVehicleStats;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  GpsPoint? _lastPosition;
  
  Timer? _activeTripCheckTimer;
  bool _isCheckingActiveTrip = false;
  
  TripBloc({
    required InitializeTrip initializeTrip,
    required StartTrip startTrip,
    required EndTrip endTrip,
    required GetCurrentTrip getCurrentTrip,
    required UpdatePeriodicTrip updatePeriodicTrip,
    required GetVehicleStats getVehicleStats,
  }) : _initializeTrip = initializeTrip,
       _startTrip = startTrip,
       _endTrip = endTrip,
       _getCurrentTrip = getCurrentTrip,
       _updatePeriodicTrip = updatePeriodicTrip,
       _getVehicleStats = getVehicleStats,
       super(TripState.initial()) {
    on<InitializeTripSystem>(_onInitializeTripSystem);
    on<StartTripEvent>(_onStartTrip);
    on<EndTripEvent>(_onEndTrip);
    on<GetCurrentTripEvent>(_onGetCurrentTrip);
    on<UpdatePeriodicTripEvent>(_onUpdatePeriodicTrip);
    on<GetVehicleStatsEvent>(_onGetVehicleStats);
  }
  
  Future<void> _onInitializeTripSystem(
    InitializeTripSystem event, 
    Emitter<TripState> emit
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    try {
      final result = await _initializeTrip();
      add(GetCurrentTripEvent());
    } catch (e) {
      emit(state.copyWith(
        status: TripStatus.error,
        error: 'Error inicializando: ${e.toString()}',
      ));
    }
  }
  
  Future<void> _onStartTrip(
    StartTripEvent event, 
    Emitter<TripState> emit
  ) async {
    print("[TripBloc] Iniciando viaje: vehicleId=${event.vehicleId}, isSimulationMode=${state.isOBDConnected}");
    emit(state.copyWith(status: TripStatus.loading));
    
    try {
      final result = await _startTrip(event.vehicleId);
      
      result.fold(
        (failure) {
          print("[TripBloc] ERROR al iniciar viaje: ${failure.message}");
          emit(state.copyWith(
            status: TripStatus.error,
            error: "Error al iniciar viaje: ${failure.message}",
          ));
        },
        (trip) {
          print("[TripBloc] Viaje iniciado correctamente: ${trip.id}");
          emit(state.copyWith(
            status: TripStatus.active,
            currentTrip: trip,
            error: null,
          ));
        }
      );
    } catch (e) {
      print("[TripBloc] Excepción al iniciar viaje: $e");
      emit(state.copyWith(
        status: TripStatus.error,
        error: "Error inesperado al iniciar viaje: $e",
      ));
    }
  }
  
  Future<void> _onEndTrip(EndTripEvent event, Emitter<TripState> emit) async {
    try {
      if (state.status == TripStatus.active && state.currentTrip != null) {
        emit(state.copyWith(status: TripStatus.loading));
        
        final result = await _endTrip(event.tripId);
        
        result.fold(
          (failure) {
            emit(state.copyWith(
              status: TripStatus.error,
              error: 'Error al finalizar el viaje: ${failure.message}',
            ));
            add(GetCurrentTripEvent());
          },
          (endedTrip) {
            print("[TripBloc] Viaje finalizado exitosamente en BLoC.");
            emit(state.copyWith(
              status: TripStatus.ready,
              currentTrip: null,
              lastCompletedTrip: endedTrip,
              error: null,
            ));
            _activeTripCheckTimer?.cancel();
            _activeTripCheckTimer = Timer(const Duration(seconds: 3), () {
              if (state.status == TripStatus.ready) {
                add(GetCurrentTripEvent());
              }
            });
            
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('last_trip_end_time', DateTime.now().toIso8601String());
            });
          }
        );
      } else {
        emit(state.copyWith(status: TripStatus.error, error: 'No hay viaje activo para finalizar'));
        add(GetCurrentTripEvent());
      }
    } catch (error) {
      emit(state.copyWith(
        status: TripStatus.error,
        error: 'Error al finalizar el viaje: $error',
      ));
    }
  }
  
  Future<void> _onGetCurrentTrip(
    GetCurrentTripEvent event, 
    Emitter<TripState> emit
  ) async {
    if (_isCheckingActiveTrip) return;
    _isCheckingActiveTrip = true;
    
    print("[TripBloc] Verificando viaje activo...");
    final result = await _getCurrentTrip();
    result.fold(
      (failure) {
        if (state.status == TripStatus.active || state.status == TripStatus.loading) {
          print("[TripBloc] No se encontró viaje activo, emitiendo TripReady.");
          emit(state.copyWith(
            status: TripStatus.ready,
            currentTrip: null,
            error: null,
          ));
        } else {
          print("[TripBloc] Error obteniendo viaje, pero el estado actual no es Activo/Cargando. Estado no cambiado.");
        }
      },
      (trip) {
        if (trip == null) {
          if (state.status == TripStatus.active || state.status == TripStatus.loading) {
            print("[TripBloc] GetCurrentTrip devolvió null, emitiendo TripReady.");
            emit(state.copyWith(
              status: TripStatus.ready,
              currentTrip: null,
              error: null,
            ));
          }
        } else {
          print("[TripBloc] Viaje activo encontrado, emitiendo TripActive.");
          emit(state.copyWith(
            status: TripStatus.active,
            currentTrip: trip,
            error: null,
          ));
        }
      },
    );
    _isCheckingActiveTrip = false;
  }
  
  Future<void> _onUpdatePeriodicTrip(
    UpdatePeriodicTripEvent event,
    Emitter<TripState> emit,
  ) async {
    if (state.status == TripStatus.active) {
      final result = await _updatePeriodicTrip(
        tripId: event.tripId,
        batchPoints: event.batchPoints,
        totalDistance: event.totalDistance,
        totalFuelConsumed: event.totalFuelConsumed,
        averageSpeed: event.averageSpeed,
        durationSeconds: event.durationSeconds,
      );
      
      result.fold(
        (failure) {
          print("[TripBloc] Error en actualización periódica: ${failure.message}");
        },
        (updatedTrip) {
          print("[TripBloc] Actualización periódica exitosa, emitiendo TripActive.");
          emit(state.copyWith(status: TripStatus.active, currentTrip: updatedTrip, error: null));
        },
      );
    } else {
      print("[TripBloc] Advertencia: Se intentó actualizar periódicamente sin estar en estado TripActive.");
    }
  }
  
  Future<void> _onGetVehicleStats(
    GetVehicleStatsEvent event,
    Emitter<TripState> emit,
  ) async {
    emit(state.copyWith(status: TripStatus.loading));
    
    final result = await _getVehicleStats(event.vehicleId);
    
    result.fold(
      (failure) => emit(state.copyWith(
        status: TripStatus.error,
        error: failure.message,
      )),
      (stats) {
        print("[TripBloc] Estadísticas del vehículo obtenidas: $stats");
        final previousStatus = state.status;
        emit(state.copyWith(
          status: previousStatus == TripStatus.loading ? TripStatus.ready : previousStatus,
          vehicleStats: stats,
          error: null,
        ));
      },
    );
  }
  
  @override
  Future<void> close() async {
    _positionStreamSubscription?.cancel();
    _activeTripCheckTimer?.cancel();
    return super.close();
  }
} 
