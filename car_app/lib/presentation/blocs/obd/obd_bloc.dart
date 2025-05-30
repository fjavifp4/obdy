// lib/presentation/blocs/obd/obd_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../domain/entities/obd_data.dart';
import '../../../domain/repositories/obd_repository.dart';
import '../../../domain/usecases/usecases.dart';
import '../../../config/core/either.dart';
import '../../../config/core/failures.dart';
import '../../../data/repositories/obd_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importar los archivos 'part'
part 'obd_event.dart';
part 'obd_state.dart';

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

// Evento interno para disparar la actualización periódica
class _TickEvent extends OBDEvent {
  final String pid;
  const _TickEvent(this.pid);
}

class OBDBloc extends Bloc<OBDEvent, OBDState> {
  final InitializeOBD initializeOBD;
  final ConnectOBD connectOBD;
  final DisconnectOBD disconnectOBD;
  final GetParameterData getParameterData;
  final GetDiagnosticTroubleCodes getDiagnosticTroubleCodes;
  final GetSupportedPids getSupportedPids;
  final OBDRepository _obdRepository;
  
  final Map<String, Timer> _parameterTimers = {};
  final Set<String> _monitoredPids = {};

  OBDBloc({
    required this.initializeOBD,
    required this.connectOBD,
    required this.disconnectOBD,
    required this.getParameterData,
    required this.getDiagnosticTroubleCodes,
    required this.getSupportedPids,
  }) : 
    _obdRepository = GetIt.I<OBDRepositoryProvider>(),
    super(const OBDState()) {
    on<InitializeOBDEvent>(_onInitializeOBD);
    on<ConnectToOBD>(_onConnectToOBD);
    on<DisconnectFromOBD>(_onDisconnectFromOBD);
    on<StartParameterMonitoring>(_onStartParameterMonitoring);
    on<StopParameterMonitoring>(_onStopParameterMonitoring);
    on<GetDTCCodes>(_onGetDTCCodes);
    on<UpdateParameterData>(_onUpdateParameterData);
    on<ClearDTCCodes>(_onClearDTCCodes);
    on<ToggleSimulationMode>(_onToggleSimulationMode);
    on<FetchSupportedPids>(_onFetchSupportedPids);
    
    // Registrar los manejadores de eventos internos
    on<_DevicesFoundEvent>(_onDevicesFound);
    on<_DeviceSearchErrorEvent>(_onDeviceSearchError);
    on<SearchingDevicesEvent>(_onSearchingDevices);
    on<_TickEvent>(_onTick);

    // Cargar estado inicial de conexión si existe
    _loadInitialConnectionState();
  }

  Future<void> _loadInitialConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool wasConnected = prefs.getBool('obd_is_connected') ?? false;
      final bool wasSimulation = prefs.getBool('obd_is_simulation') ?? false;
      
      print("[OBDBloc] Estado cargado: conectado=$wasConnected, simulación=$wasSimulation");

      // Asegurar que el modo del provider coincide con el guardado
      final provider = GetIt.I<OBDRepositoryProvider>();
      if (provider.isSimulationMode != wasSimulation) {
          print("[OBDBloc] El modo del provider no coincide con el guardado. Ajustando provider a $wasSimulation");
          provider.setSimulationMode(wasSimulation);
      }

      // Si el estado guardado indica que estábamos conectados, emitir estado conectado
      // PERO solo si el modo coincide.
      // Si estábamos conectados en modo real, el usuario tendrá que reconectar manualmente.
      // Si estábamos en simulación, podemos emitir conectado.
      if (wasConnected && wasSimulation) {
        emit(state.copyWith(
          status: OBDStatus.connected,
          isSimulationMode: true,
        ));
      } else {
         // Si no estábamos conectados o estábamos en modo real, emitir estado inicial
        emit(state.copyWith(
          status: OBDStatus.initial,
          isSimulationMode: wasSimulation,
        ));
         // Iniciar la búsqueda de dispositivos si estamos en modo real
        if (!wasSimulation) {
          add(InitializeOBDEvent());
        }
      }
    } catch (e) {
      print("[OBDBloc] Error cargando estado inicial: $e");
       // Emitir estado inicial por defecto en caso de error
        emit(state.copyWith(status: OBDStatus.initial));
    }
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
      // no desconectamos para mantener la simulación entre navegaciones, pero solo si seguimos en modo simulación
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
      print("[OBDBloc] No se puede iniciar monitoreo ($event.pid): OBD no conectado");
      // Opcional: emitir error si no está conectado?
      return;
    }

    final pid = event.pid;
    if (_monitoredPids.contains(pid)) {
      print("[OBDBloc] Ya se está monitoreando el PID: $pid");
      return; // Ya está monitoreado, no hacer nada
    }

    print("[OBDBloc] Iniciando monitoreo para PID: $pid");
    _monitoredPids.add(pid);

    // Emitir un estado inicial para este parámetro si no existe
    if (!state.parametersData.containsKey(pid)) {
        final initialParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
        initialParams[pid] = {
          'value': 0.0,
          'unit': '',
          'description': 'Iniciando...',
        };
        emit(state.copyWith(parametersData: initialParams));
    }

    // Iniciar el Timer periódico
    _parameterTimers[pid]?.cancel(); // Cancelar timer anterior si existe por alguna razón
    _parameterTimers[pid] = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Verificar si aún debemos monitorear y si estamos conectados
      if (_monitoredPids.contains(pid) && state.status == OBDStatus.connected && !isClosed) {
         print("[OBDBloc] Timer tick para $pid");
         add(_TickEvent(pid)); // Disparar evento Tick
      } else {
        print("[OBDBloc] Cancelando timer para $pid (desconectado, cerrado o no monitoreado)");
        timer.cancel(); // Detener timer si ya no aplica
        _parameterTimers.remove(pid);
      }
    });

    // Opcional: realizar una solicitud inicial inmediata sin esperar al primer tick
    add(_TickEvent(pid));

  }

  // Nuevo manejador para el evento _TickEvent
  Future<void> _onTick(_TickEvent event, Emitter<OBDState> emit) async {
      final pid = event.pid;
      print("[OBDBloc] Solicitando datos para $pid desde Tick");

      // Usamos el use case GetParameterData que devuelve un Stream
      // Tomamos solo el primer (y único) valor del stream resultante para esta solicitud puntual
      try {
         // El Stream debería emitir un solo valor (o un error)
         final stream = getParameterData(pid);
         // Escuchar el stream y añadir UpdateParameterData cuando llegue el dato o error
         // Usamos .first para asegurar que solo procesamos una emisión por tick
         stream.first.then((eitherResult) {
            if (!isClosed && _monitoredPids.contains(pid)) { // Doble check
               add(UpdateParameterData(pid, eitherResult));
            }
         }).catchError((error) {
             if (!isClosed && _monitoredPids.contains(pid)) {
                print("[OBDBloc] Error en stream.first para $pid: $error");
                add(UpdateParameterData(pid, Either.left(OBDFailure("Error en Tick: $error"))));
             }
         });
      } catch (e) {
          print("[OBDBloc] Excepción al llamar a getParameterData en Tick para $pid: $e");
           if (!isClosed && _monitoredPids.contains(pid)) {
              add(UpdateParameterData(pid, Either.left(OBDFailure("Excepción en Tick: $e"))));
           }
      }
  }

  void _onUpdateParameterData(
    UpdateParameterData event,
    Emitter<OBDState> emit,
  ) {
    final pid = event.pid;

    // Solo actualizar si todavía estamos monitoreando este PID
    if (!_monitoredPids.contains(pid)) {
      print("[OBDBloc] Recibido UpdateParameterData para $pid pero ya no se monitorea. Ignorando.");
      return;
    }

    final eitherResult = event.result;
    final updatedParams = Map<String, Map<String, dynamic>>.from(state.parametersData);

    eitherResult.fold(
      (failure) {
        // Actualizar solo si el valor es diferente o es la primera vez
        if (!updatedParams.containsKey(pid) || updatedParams[pid]?['description'] != 'Error: ${failure.message}') {
            updatedParams[pid] = {
              'value': updatedParams[pid]?['value'] ?? 0.0, // Mantener valor anterior si es error?
              'unit': updatedParams[pid]?['unit'] ?? '',
              'description': 'Error: ${failure.message}',
            };
            emit(state.copyWith(
              parametersData: updatedParams,
              error: failure.message, // Actualizar el último error general
            ));
        }
        print("[OBDBloc] Error actualizado para $pid: ${failure.message}");
      },
      (data) { // data es OBDData
        print("[OBDBloc] DEBUG: Recibido OBDData para $pid: value=${data.value}, unit='${data.unit}', desc='${data.description}'");
        // Actualizar solo si el valor o la unidad han cambiado
         if (!updatedParams.containsKey(pid) ||
             updatedParams[pid]?['value'] != data.value ||
             updatedParams[pid]?['unit'] != data.unit) {
              updatedParams[pid] = {
                'value': data.value,
                'unit': data.unit,
                'description': data.description,
              };
              emit(state.copyWith(
                parametersData: updatedParams,
                error: null, // Limpiar error general si tuvimos éxito
              ));
         }
        print("[OBDBloc] Datos actualizados para $pid: ${data.value} ${data.unit}");
      }
    );
  }

  Future<void> _onStopParameterMonitoring(
    StopParameterMonitoring event,
    Emitter<OBDState> emit,
  ) async {
    final pid = event.pid;
    print("[OBDBloc] Deteniendo monitoreo para PID: $pid");

    _monitoredPids.remove(pid);
    _parameterTimers[pid]?.cancel();
    _parameterTimers.remove(pid);

    // Opcional: ¿Quitar los datos del estado al detener monitoreo?
    // Depende de si quieres que el último valor persista en la UI
    // final updatedParams = Map<String, Map<String, dynamic>>.from(state.parametersData);
    // updatedParams.remove(pid);
    // emit(state.copyWith(parametersData: updatedParams));

    // Por ahora, no quitamos los datos, solo detenemos la actualización.
  }

  Future<void> _onGetDTCCodes(
    GetDTCCodes event,
    Emitter<OBDState> emit,
  ) async {
    if (!_obdRepository.isConnected) {
      emit(state.copyWith(
        error: 'Dispositivo OBD no conectado',
        dtcCodes: [], // Limpiar códigos previos si los hubiera
        isLoading: false, // Asegurar que no quede como cargando
      ));
      return;
    }
    
    emit(state.copyWith(isLoading: true, error: null)); // Indicar carga
    
    try {
      final result = await getDiagnosticTroubleCodes();
      
      await result.fold(
        (failure) async {
          emit(state.copyWith(
            error: failure.message,
            dtcCodes: [], // Limpiar códigos en caso de error
            isLoading: false,
          ));
        },
        (codes) async {
          emit(state.copyWith(
            dtcCodes: codes, 
            error: null,
            isLoading: false,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        error: 'Excepción al obtener DTCs: ${e.toString()}',
        dtcCodes: [],
        isLoading: false,
      ));
    }
  }

  Future<void> _onClearDTCCodes(
    ClearDTCCodes event,
    Emitter<OBDState> emit,
  ) async {
    // Aquí iría la lógica para enviar el comando OBD para borrar códigos (ej. '04')
    // Por ahora, solo limpiaremos la lista en el estado
    emit(state.copyWith(dtcCodes: [], error: null));
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
        
        // Asegurarse de que todas las suscripciones anteriores se cancelen
        for (final timer in _parameterTimers.values) {
          timer.cancel();
        }
        _parameterTimers.clear();
        _monitoredPids.clear();
      }
      
      // Obtener la instancia del OBDRepositoryProvider desde GetIt
      final repositoryProvider = GetIt.I.get<OBDRepositoryProvider>();
      
      // Si estamos cambiando de simulación a real, añadir una pequeña pausa para garantizar que
      // todos los recursos de simulación se liberen completamente
      if (state.isSimulationMode && !newIsSimulationMode) {
        print("[OBDBloc] Pausando brevemente para asegurar que la simulación se detenga completamente");
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Limpieza completa de estado
      final cleanState = OBDState(
        isSimulationMode: newIsSimulationMode,
        status: OBDStatus.initialized,
        isLoading: false,
        parametersData: {}, // Limpiar todos los datos de parámetros
        supportedPids: null, // Forzar recarga de PIDs soportados
        devices: [], // Limpiar dispositivos detectados
        dtcCodes: [], // Limpiar códigos de error
      );
      
      // Cambiar el modo en el provider
      repositoryProvider.setSimulationMode(newIsSimulationMode);
      
      // Emitimos el nuevo estado limpio
      emit(cleanState);
      
      // Guardar el estado actual en preferencias
      _saveCurrentConnectionState();
      
      // Solo si activamos modo simulación, nos conectamos automáticamente
      if (newIsSimulationMode) {
        print("[OBDBloc] Conectando automáticamente en modo simulación");
        add(ConnectToOBD());
      } else {
        print("[OBDBloc] En modo real, esperando a que el usuario inicie la conexión");
        // En modo real, inicializamos el adaptador pero no conectamos automáticamente
        add(InitializeOBDEvent());
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: "Error al cambiar de modo: $e",
      ));
    }
  }

  // Método para guardar el estado actual en preferencias
  Future<void> _saveCurrentConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('obd_is_simulation', state.isSimulationMode);
      await prefs.setBool('obd_is_connected', state.status == OBDStatus.connected);
      print("[OBDBloc] Estado guardado: simulación=${state.isSimulationMode}, conectado=${state.status == OBDStatus.connected}");
    } catch (e) {
      print("[OBDBloc] Error al guardar estado: $e");
    }
  }

  Future<void> _onFetchSupportedPids(
    FetchSupportedPids event,
    Emitter<OBDState> emit,
  ) async {
    if (state.status != OBDStatus.connected) {
      emit(state.copyWith(
        error: 'No se puede obtener PIDs soportados: OBD no conectado',
      ));
      return;
    }
    
    // Emitir estado de carga sin modificar el estado de conexión
    emit(state.copyWith(
      isLoading: true,
      error: null, // Limpiar errores anteriores
    ));
    
    try {
      // Añadir timeout para la operación
      final completer = Completer<Either<Failure, List<String>>>();
      
      // Iniciar la solicitud
      getSupportedPids().then(completer.complete).catchError(completer.completeError);
      
      // Esperar el resultado con timeout de 10 segundos
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("[OBDBloc] Timeout al obtener PIDs soportados");
          return Either.left(OBDFailure("Tiempo de espera agotado al obtener PIDs soportados"));
        }
      );
      
      result.fold(
        (failure) {
          print("[OBDBloc] Error al obtener PIDs soportados: ${failure.message}");
          emit(state.copyWith(
            isLoading: false,
            error: failure.message,
          ));
        },
        (pids) {
          print("[OBDBloc] PIDs soportados obtenidos: ${pids.length}");
          emit(state.copyWith(
            isLoading: false,
            supportedPids: pids,
            error: null, // Limpiar errores previos
          ));
        }
      );
    } catch (e) {
      print("[OBDBloc] Excepción al obtener PIDs soportados: $e");
      emit(state.copyWith(
        isLoading: false,
        error: "Error al obtener PIDs soportados: $e",
      ));
    }
  }

  @override
  Future<void> close() async {
    print("[OBDBloc] Cerrando BLoC y cancelando timers...");
    // Cancelar todos los timers activos
    for (final timer in _parameterTimers.values) {
      timer.cancel();
    }
    _parameterTimers.clear();
    _monitoredPids.clear();

    // Si estamos conectados, desconectar
    if (state.status == OBDStatus.connected || state.status == OBDStatus.connecting) {
       print("[OBDBloc] Desconectando OBD al cerrar BLoC...");
       await _obdRepository.disconnect();
    }

    return super.close();
  }
}
