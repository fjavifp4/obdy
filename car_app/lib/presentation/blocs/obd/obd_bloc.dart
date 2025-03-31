// lib/presentation/blocs/obd/obd_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../domain/usecases/usecases.dart';
import 'obd_event.dart';
import 'obd_state.dart';
import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/data/repositories/obd_repository_provider.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Eventos internos para búsqueda de dispositivos
class _DevicesFoundEvent extends OBDEvent {
  final List<BluetoothDevice> devices;
  _DevicesFoundEvent(this.devices);
}

class _DeviceSearchErrorEvent extends OBDEvent {
  final String error;
  _DeviceSearchErrorEvent(this.error);
}

class SearchingDevicesEvent extends OBDEvent {}

class OBDBloc extends Bloc<OBDEvent, OBDState> {
  final InitializeOBD initializeOBD;
  final ConnectOBD connectOBD;
  final DisconnectOBD disconnectOBD;
  final GetParameterData getParameterData;
  final GetDiagnosticTroubleCodes getDiagnosticTroubleCodes;
  final OBDRepository _obdRepository;
  
  final Map<String, StreamSubscription> _dataSubscriptions = {};

  OBDBloc({
    required this.initializeOBD,
    required this.connectOBD,
    required this.disconnectOBD,
    required this.getParameterData,
    required this.getDiagnosticTroubleCodes,
  }) : 
    _obdRepository = GetIt.I<OBDRepositoryProvider>(),
    super(const OBDState.initial()) {
    on<InitializeOBDEvent>(_onInitializeOBD);
    on<ConnectToOBD>(_onConnectToOBD);
    on<DisconnectFromOBD>(_onDisconnectFromOBD);
    on<StartParameterMonitoring>(_onStartParameterMonitoring);
    on<StopParameterMonitoring>(_onStopParameterMonitoring);
    on<GetDTCCodes>(_onGetDTCCodes);
    on<UpdateParameterData>(_onUpdateParameterData);
    on<ClearDTCCodes>(_onClearDTCCodes);
    on<ToggleSimulationMode>(_onToggleSimulationMode);
    
    // Registrar los manejadores de eventos internos
    on<_DevicesFoundEvent>(_onDevicesFound);
    on<_DeviceSearchErrorEvent>(_onDeviceSearchError);
    on<SearchingDevicesEvent>(_onSearchingDevices);
  }

  Future<void> _onInitializeOBD(
    InitializeOBDEvent event,
    Emitter<OBDState> emit,
  ) async {
    try {
      // Si ya estamos inicializando o buscando, no hacer nada
      if (state.status == OBDStatus.initial && state.isLoading) {
        return;
      }
      
      emit(state.copyWith(
        status: OBDStatus.initial,
        error: null,
        isLoading: true,
      ));

      // Inicializar el repositorio
      await _obdRepository.initialize();
      
      // Si estamos en modo simulación, emitir inicializado y conectar automáticamente
      if (state.isSimulationMode) {
        emit(state.copyWith(
          status: OBDStatus.initialized,
          isLoading: false,
          error: null,
        ));
        
        print("[OBDBloc] Inicializado en modo simulación, saltando búsqueda Bluetooth");
        // Conectar automáticamente en modo simulación
        add(ConnectToOBD());
        return;
      }
      
      // Emitir estado initialized inmediatamente
      emit(state.copyWith(
        status: OBDStatus.initialized,
        isLoading: false,
        error: null,
      ));
      
      // Buscar dispositivos en segundo plano
      _searchDevices();
    } catch (e) {
      print("[OBDBloc] Error en inicialización: $e");
      emit(state.copyWith(
        status: OBDStatus.error,
        error: e.toString(),
        isLoading: false,
      ));
    }
  }
  
  // Función separada para buscar dispositivos
  void _searchDevices() {
    // Emitir un evento para indicar que estamos buscando dispositivos
    add(SearchingDevicesEvent());
    
    _obdRepository.getAvailableDevices().then((devices) {
      if (!isClosed) {
        add(_DevicesFoundEvent(devices));
      }
    }).catchError((e) {
      if (!isClosed) {
        add(_DeviceSearchErrorEvent("Error al buscar dispositivos: $e"));
      }
    });
  }
  
  // Nuevo evento para indicar búsqueda en progreso
  void _onSearchingDevices(
    SearchingDevicesEvent event,
    Emitter<OBDState> emit,
  ) {
    emit(state.copyWith(
      isLoading: true,
    ));
  }
  
  // Manejadores para los eventos internos de búsqueda
  void _onDevicesFound(_DevicesFoundEvent event, Emitter<OBDState> emit) {
    emit(state.copyWith(
      devices: event.devices,
      isLoading: false,
      error: event.devices.isEmpty ? "No se encontraron dispositivos OBD cercanos" : null,
    ));
  }
  
  void _onDeviceSearchError(_DeviceSearchErrorEvent event, Emitter<OBDState> emit) {
    emit(state.copyWith(
      error: event.error,
    ));
  }

  Future<void> _onConnectToOBD(
    ConnectToOBD event,
    Emitter<OBDState> emit,
  ) async {
    try {
      if (state.status != OBDStatus.initialized) {
        return;
      }
      
      emit(state.copyWith(status: OBDStatus.connecting));
      
      print("[OBDBloc] Conectando a OBD...");
      final result = await _obdRepository.connect();
      
      if (result) {
        print("[OBDBloc] Conexión exitosa a OBD");
        emit(state.copyWith(
          status: OBDStatus.connected,
          error: null,
          parametersData: {},
        ));
        
        // Guardar información de conexión en preferencias para mantener entre navegaciones
        _saveConnectionState(isConnected: true, isSimulation: state.isSimulationMode);
      } else {
        print("[OBDBloc] Fallo al conectar a OBD");
        emit(state.copyWith(
          status: OBDStatus.error,
          error: 'No se pudo conectar al dispositivo OBD',
        ));
      }
    } catch (e) {
      print("[OBDBloc] Error al conectar a OBD: $e");
      emit(state.copyWith(
        status: OBDStatus.error,
        error: 'Error: $e',
      ));
    }
  }

  Future<void> _saveConnectionState({required bool isConnected, required bool isSimulation}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('obd_is_connected', isConnected);
      await prefs.setBool('obd_is_simulation', isSimulation);
      print("[OBDBloc] Estado de conexión guardado: conectado=$isConnected, simulación=$isSimulation");
    } catch (e) {
      print("[OBDBloc] Error al guardar estado de conexión: $e");
    }
  }

  Future<void> _onDisconnectFromOBD(
    DisconnectFromOBD event,
    Emitter<OBDState> emit,
  ) async {
    try {
      // Si estamos en modo simulación y el evento de desconexión viene del dispose de la pantalla,
      // no desconectamos para mantener la simulación entre navegaciones
      if (state.isSimulationMode && event is DisconnectFromOBDPreserveSimulation) {
        print("[OBDBloc] Preservando simulación durante navegación, sin desconexión real");
        return;
      }
      
      print("[OBDBloc] Desconectando de OBD");
      await _obdRepository.disconnect();
      
      emit(state.copyWith(
        status: OBDStatus.disconnected,
        parametersData: {},
      ));
      
      // Actualizar preferencias
      _saveConnectionState(isConnected: false, isSimulation: state.isSimulationMode);
      
      print("[OBDBloc] Desconexión completada");
    } catch (e) {
      print("[OBDBloc] Error al desconectar: $e");
      emit(state.copyWith(
        status: OBDStatus.error,
        error: 'Error al desconectar: $e',
      ));
    }
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

  Future<void> _onToggleSimulationMode(
    ToggleSimulationMode event,
    Emitter<OBDState> emit,
  ) async {
    // Cambiar el modo de simulación
    final newIsSimulationMode = !state.isSimulationMode;
    
    print("[OBDBloc] Cambiando a modo ${newIsSimulationMode ? 'simulación' : 'real'}");
    
    // Notificamos que estamos cambiando de modo
    emit(state.copyWith(
      isLoading: true,
    ));
    
    try {
      // Si estamos conectados, primero desconectamos
      if (state.status == OBDStatus.connected) {
        print("[OBDBloc] Desconectando antes de cambiar de modo");
        await disconnectOBD();
      }
      
      // Obtener la instancia del OBDRepositoryProvider desde GetIt
      final repositoryProvider = GetIt.I.get<OBDRepositoryProvider>();
      
      // Cambiar el modo en el provider
      repositoryProvider.setSimulationMode(newIsSimulationMode);
      
      // Emitimos el cambio de modo
      emit(state.copyWith(
        isSimulationMode: newIsSimulationMode,
        status: OBDStatus.initialized,
        isLoading: false,
      ));
      
      // Solo si activamos modo simulación, nos conectamos automáticamente
      if (newIsSimulationMode) {
        print("[OBDBloc] Conectando automáticamente en modo simulación");
        add(ConnectToOBD());
      } else {
        print("[OBDBloc] En modo real, esperando a que el usuario inicie la conexión");
        // En modo real, no conectamos automáticamente, esperamos a que el usuario lo haga
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: "Error al cambiar de modo: $e",
      ));
    }
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