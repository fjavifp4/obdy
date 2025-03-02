// lib/presentation/blocs/obd/obd_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/usecases.dart';
import 'obd_event.dart';
import 'obd_state.dart';
import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';

class OBDBloc extends Bloc<OBDEvent, OBDState> {
  final InitializeOBD initializeOBD;
  final ConnectOBD connectOBD;
  final DisconnectOBD disconnectOBD;
  final GetParameterData getParameterData;
  final GetDiagnosticTroubleCodes getDiagnosticTroubleCodes;
  
  final Map<String, StreamSubscription> _dataSubscriptions = {};

  OBDBloc({
    required this.initializeOBD,
    required this.connectOBD,
    required this.disconnectOBD,
    required this.getParameterData,
    required this.getDiagnosticTroubleCodes,
  }) : super(const OBDState.initial()) {
    on<InitializeOBDEvent>(_onInitializeOBD);
    on<ConnectToOBD>(_onConnectToOBD);
    on<DisconnectFromOBD>(_onDisconnectFromOBD);
    on<StartParameterMonitoring>(_onStartParameterMonitoring);
    on<StopParameterMonitoring>(_onStopParameterMonitoring);
    on<GetDTCCodes>(_onGetDTCCodes);
    on<UpdateParameterData>(_onUpdateParameterData);
    on<ClearDTCCodes>(_onClearDTCCodes);
  }

  Future<void> _onInitializeOBD(
    InitializeOBDEvent event,
    Emitter<OBDState> emit,
  ) async {
    final result = await initializeOBD();
    
    result.fold(
      (failure) => emit(state.copyWith(
        status: OBDStatus.error,
        error: failure.message,
      )),
      (_) => emit(state.copyWith(status: OBDStatus.initialized))
    );
  }

  Future<void> _onConnectToOBD(
    ConnectToOBD event,
    Emitter<OBDState> emit,
  ) async {
    if (state.status != OBDStatus.initialized) {
      emit(state.copyWith(
        error: 'No se puede conectar: El OBD no está inicializado',
      ));
      return;
    }
    
    emit(state.copyWith(status: OBDStatus.connecting));
    
    final result = await connectOBD();
    
    result.fold(
      (failure) => emit(state.copyWith(
        status: OBDStatus.error,
        error: failure.message,
      )),
      (_) => emit(state.copyWith(status: OBDStatus.connected))
    );
  }

  Future<void> _onDisconnectFromOBD(
    DisconnectFromOBD event,
    Emitter<OBDState> emit,
  ) async {
    // Cancelar todas las suscripciones activas
    for (final subscription in _dataSubscriptions.values) {
      await subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    final result = await disconnectOBD();
    
    result.fold(
      (failure) => emit(state.copyWith(
        error: failure.message,
      )),
      (_) => emit(state.copyWith(status: OBDStatus.disconnected))
    );
  }

  void _onStartParameterMonitoring(
    StartParameterMonitoring event,
    Emitter<OBDState> emit,
  ) {
    if (state.status != OBDStatus.connected) {
      emit(state.copyWith(
        error: 'No se puede iniciar monitoreo: OBD no conectado',
      ));
      return;
    }

    try {
      // Cancelar suscripción existente para este PID
      _dataSubscriptions[event.pid]?.cancel();
      _dataSubscriptions.remove(event.pid);
      
      // Emitir un estado inicial para este parámetro
      final initialParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
      initialParams[event.pid] = {
        'value': 0.0,
        'unit': '',
        'description': 'Iniciando monitoreo...',
      };
      
      emit(state.copyWith(
        parametersData: initialParams,
      ));
      
      // Usar el evento UpdateParameterData para actualizar los datos
      _dataSubscriptions[event.pid] = getParameterData(event.pid).listen(
        (eitherResult) {
          if (isClosed) return;
          
          add(UpdateParameterData(event.pid, eitherResult));
        },
        onError: (error) {
          if (!isClosed) {
            print("[OBDBloc] Error al monitorear ${event.pid}: $error");
            final errorData = {
              'value': 0.0,
              'unit': '',
              'description': 'Error: $error',
            };
            add(UpdateParameterData(
              event.pid, 
              Either.left(OBDFailure("Error al monitorear: $error"))
            ));
          }
        },
      );
    } catch (e) {
      print("[OBDBloc] Excepción al iniciar monitoreo: $e");
      if (!isClosed) {
        final updatedParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
        updatedParams[event.pid] = {
          'value': 0.0,
          'unit': '',
          'description': 'Error: $e',
        };
        emit(state.copyWith(
          parametersData: updatedParams,
          error: "Error al iniciar monitoreo: $e",
        ));
      }
    }
  }

  void _onUpdateParameterData(
    UpdateParameterData event,
    Emitter<OBDState> emit,
  ) {
    final pid = event.pid;
    final eitherResult = event.result;
    
    // Crear una copia de los datos actuales
    final updatedParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
    
    eitherResult.fold(
      (failure) {
        updatedParams[pid] = {
          'value': 0.0,
          'unit': '',
          'description': 'Error: ${failure.message}',
        };
        emit(state.copyWith(
          parametersData: updatedParams,
          error: failure.message,
        ));
        print("[OBDBloc] Error actualizado para $pid: ${failure.message}");
      },
      (data) {
        updatedParams[pid] = {
          'value': data.value,
          'unit': data.unit,
          'description': data.description,
        };
        emit(state.copyWith(
          parametersData: updatedParams,
        ));
        print("[OBDBloc] Datos actualizados para $pid: ${data.value} ${data.unit}");
      }
    );
  }

  Future<void> _onStopParameterMonitoring(
    StopParameterMonitoring event,
    Emitter<OBDState> emit,
  ) async {
    await _dataSubscriptions[event.pid]?.cancel();
    _dataSubscriptions.remove(event.pid);
    
    // Eliminar los datos de este parámetro
    final updatedParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
    updatedParams.remove(event.pid);
    
    emit(state.copyWith(
      parametersData: updatedParams,
    ));
  }

  Future<void> _onGetDTCCodes(
    GetDTCCodes event,
    Emitter<OBDState> emit,
  ) async {
    if (state.status != OBDStatus.connected) {
      emit(state.copyWith(
        error: 'No se puede obtener códigos DTC: OBD no conectado',
      ));
      return;
    }
    
    emit(state.copyWith(isLoading: true));
    
    final result = await getDiagnosticTroubleCodes();
    
    result.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        error: failure.message,
      )),
      (codes) => emit(state.copyWith(
        isLoading: false,
        dtcCodes: codes,
      ))
    );
  }

  void _onClearDTCCodes(
    ClearDTCCodes event,
    Emitter<OBDState> emit,
  ) {
    emit(state.copyWith(
      dtcCodes: [],
    ));
  }

  @override
  Future<void> close() async {
    // Cancelar todas las suscripciones
    for (final subscription in _dataSubscriptions.values) {
      await subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    return super.close();
  }
}