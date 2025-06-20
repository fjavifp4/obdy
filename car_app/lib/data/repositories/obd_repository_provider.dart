import 'package:obdy/domain/repositories/obd_repository.dart';
import 'package:obdy/data/repositories/obd_repository_mock.dart';
import 'package:obdy/data/repositories/obd_repository_impl.dart';
import 'package:obdy/domain/entities/obd_data.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Clase que proporciona la implementación correcta del OBDRepository
/// según si estamos en modo simulación o real.
class OBDRepositoryProvider implements OBDRepository {
  // La implementación mock siempre está disponible para el modo simulación
  final OBDRepositoryMock _mockRepository = OBDRepositoryMock();
  
  // La implementación real para el modo real
  final OBDRepository _realRepository;
  
  // Indica si estamos en modo simulación
  bool _isSimulationMode = false;
  
  // Constructor que acepta una implementación real opcional
  OBDRepositoryProvider({OBDRepository? realRepository}) 
      : _realRepository = realRepository ?? OBDRepositoryImpl();
  
  // Getter para verificar si estamos en modo simulación
  bool get isSimulationMode => _isSimulationMode;
  
  // Método para cambiar el modo
  void setSimulationMode(bool isSimulation) async {
    // Solo actualizamos si el modo cambia
    if (_isSimulationMode != isSimulation) {
      print("[OBDRepositoryProvider] Cambiando a modo: ${isSimulation ? 'Simulación' : 'Real'}");
      
      // Si estamos cambiando de simulación a real, primero desconectar la simulación
      if (_isSimulationMode && !isSimulation) {
        print("[OBDRepositoryProvider] Deteniendo simulación activa antes de cambiar a modo real");
        // Forzar desconexión completa del mock para detener la simulación
        await _mockRepository.disconnect();
        
        // Asegurarse de que todos los recursos de la simulación sean liberados
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _isSimulationMode = isSimulation;
    }
  }
  
  // Implementación de los métodos del OBDRepository delegando a la implementación adecuada
  @override
  Future<void> initialize() async {
    // Siempre intentamos detener cualquier simulación previa que pudiera estar ejecutándose
    try {
      print("[OBDRepositoryProvider] Deteniendo cualquier simulación previa");
      await _mockRepository.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print("[OBDRepositoryProvider] Error al detener simulación previa: $e");
      // Continuamos de todos modos
    }
    
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Inicializando en modo simulación");
      return _mockRepository.initialize();
    } else {
      print("[OBDRepositoryProvider] Inicializando en modo real");
      try {
        return await _realRepository.initialize();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al inicializar en modo real: $e");
        print("[OBDRepositoryProvider] Fallback a mock por error de inicialización");
        return _mockRepository.initialize();
      }
    }
  }
  
  @override
  Future<bool> connect() async {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Conectando en modo simulación");
      return _mockRepository.connect();
    } else {
      print("[OBDRepositoryProvider] Conectando en modo real");
      try {
        final result = await _realRepository.connect();
        if (!result) {
          print("[OBDRepositoryProvider] No se pudo establecer conexión con dispositivo OBD");
          return false;
        }
        return result;
      } catch (e) {
        print("[OBDRepositoryProvider] Error al conectar en modo real: $e");
        // En lugar de propagar la excepción, simplemente retornamos false
        return false;
      }
    }
  }
  
  @override
  Future<void> disconnect() async {
    // Siempre desconectamos ambos repositorios para asegurar que no haya interferencia
    try {
      // Siempre desconectar el mock para evitar que quede simulación activa en segundo plano
      print("[OBDRepositoryProvider] Desconectando modo simulación para prevenir interferencias");
      await _mockRepository.disconnect();
    } catch (e) {
      print("[OBDRepositoryProvider] Error al desconectar simulación: $e");
    }
    
    if (!_isSimulationMode) {
      print("[OBDRepositoryProvider] Desconectando en modo real");
      try {
        return await _realRepository.disconnect();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al desconectar en modo real: $e");
        // No throw exception en desconexión, solo loggear
      }
    }
  }
  
  @override
  Stream<OBDData> getParameterData(String pid) {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Obteniendo datos para $pid en modo simulación");
      return _mockRepository.getParameterData(pid);
    } else {
      print("[OBDRepositoryProvider] Obteniendo datos para $pid en modo real");
      try {
        return _realRepository.getParameterData(pid);
      } catch (e) {
        print("[OBDRepositoryProvider] Error al obtener datos en modo real: $e");
        throw Exception("No se pueden obtener datos del dispositivo OBD: $e");
      }
    }
  }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Obteniendo códigos DTC en modo simulación");
      return _mockRepository.getDiagnosticTroubleCodes();
    } else {
      print("[OBDRepositoryProvider] Obteniendo códigos DTC en modo real");
      try {
        return _realRepository.getDiagnosticTroubleCodes();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al obtener códigos DTC en modo real: $e");
        throw Exception("No se pueden obtener códigos de error del dispositivo OBD: $e");
      }
    }
  }
  
  @override
  Future<List<String>> getSupportedPids() {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Obteniendo PIDs soportados en modo simulación");
      return _mockRepository.getSupportedPids();
    } else {
      print("[OBDRepositoryProvider] Obteniendo PIDs soportados en modo real");
      try {
        return _realRepository.getSupportedPids();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al obtener PIDs soportados en modo real: $e");
        // Devolver lista vacía o lanzar excepción dependiendo del comportamiento deseado
        throw Exception("No se pueden obtener PIDs soportados del dispositivo OBD: $e");
        // return Future.value([]); 
      }
    }
  }
  
  @override
  bool get isConnected {
    if (_isSimulationMode) {
      return _mockRepository.isConnected;
    } else {
      return _realRepository.isConnected;
    }
  }

  @override
  Future<List<BluetoothDevice>> getAvailableDevices() {
    return _realRepository.getAvailableDevices();
  }
} 
