import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:collection/collection.dart';

import 'package:car_app/domain/entities/obd_data.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';

/// Implementación del repositorio OBD que utiliza flutter_blue_plus para
/// comunicarse con un adaptador OBD-II a través de Bluetooth.
class OBDRepositoryImpl implements OBDRepository {
  // UUIDs como objetos Guid para comparación directa
  static final Guid _sppServiceGuid = Guid("00001101-0000-1000-8000-00805F9B34FB");
  static final Guid _ffe0ServiceGuid = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final Guid _fff0ServiceGuid = Guid("0000FFF0-0000-1000-8000-00805F9B34FB");

  static final Guid _ffe1CharacteristicGuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");
  static final Guid _fff1CharacteristicGuid = Guid("0000FFF1-0000-1000-8000-00805F9B34FB"); // RX común
  static final Guid _fff2CharacteristicGuid = Guid("0000FFF2-0000-1000-8000-00805F9B34FB"); // TX común
  static final Guid _deviceNameCharacteristicGuid = Guid("00002A00-0000-1000-8000-00805F9B34FB");

  // UUIDs específicos para adapatadores OBD-II
  final List<String> _possibleServiceUuids = [
    "0000FFE0-0000-1000-8000-00805F9B34FB", // SPP
    "0000FFFF-0000-1000-8000-00805F9B34FB", // Común en ELM327
    "00001101-0000-1000-8000-00805F9B34FB"  // SPP estándar
  ];
  
  final List<String> _possibleCharacteristicUuids = [
    "0000FFE1-0000-1000-8000-00805F9B34FB", // SPP
    "0000FFFF-0000-1000-8000-00805F9B34FB", // Común en ELM327
  ];

  // Estado de la conexión
  BluetoothDevice? _device;
  // Separar características para transmisión (TX) y recepción (RX)
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Completer<void>? _connectionCompleter;
  final BehaviorSubject<bool> _isConnectedController = BehaviorSubject.seeded(false);
  final BehaviorSubject<String> _responseBuffer = BehaviorSubject.seeded("");
  Completer<String>? _commandCompleter;
  Timer? _commandTimeoutTimer;
  bool _isConnecting = false;
  Completer<void>? _commandLock;
  
  // Timeout para comandos
  final Duration _commandTimeout = const Duration(seconds: 5);
  final Duration _connectionTimeout = const Duration(seconds: 10);
  
  // Constructor
  OBDRepositoryImpl();
  
  @override
  Future<void> initialize() async {
    if (!await _isBluetoothEnabled()) {
      throw Exception("Bluetooth no está encendido");
    }
  }
  
  Future<bool> _isBluetoothEnabled() async {
    try {
      return await FlutterBluePlus.isOn;
    } catch (e) {
      debugPrint("[OBDImpl] Error al verificar estado de Bluetooth: $e");
      return false;
    }
  }
  
  @override
  bool get isConnected => _isConnectedController.value;
  
  @override
  Future<bool> connect() async {
    if (isConnected || _isConnecting) {
      print("[OBDImpl] Ya conectado o conectando.");
      return isConnected;
    }
    _isConnecting = true;
    print("[OBDImpl] Iniciando conexión...");

    try {
      final devices = await _scanForOBDDevices();
      if (devices.isEmpty) {
        print("[OBDImpl] No se encontraron dispositivos OBD.");
        _isConnecting = false;
        return false;
      }
      
      _device = _findBestOBDDevice(devices);
      if (_device == null) {
        print("[OBDImpl] No se pudo seleccionar un dispositivo OBD.");
        _isConnecting = false;
        return false;
      }

      // Limpiar estado previo por si acaso
      _cleanupConnection();
      _isConnectedController.add(false); // Asegurar estado inicial

      print("[OBDImpl] Conectando a ${_device!.remoteId} (${_device!.platformName})...");

      // Configurar listener ANTES de conectar
      _connectionStateSubscription = _device!.connectionState.listen((state) {
        print("[OBDImpl] Estado de conexión FBP recibido: $state");
        bool currentlyConnected = (state == BluetoothConnectionState.connected);
        
        // Actualizar el BehaviorSubject solo si el estado cambia
        if (_isConnectedController.value != currentlyConnected) {
          _isConnectedController.add(currentlyConnected);
          print("[OBDImpl] Estado interno actualizado a: ${currentlyConnected ? 'Conectado' : 'Desconectado'}");
          
          // Si nos desconectamos inesperadamente, limpiar
          if (!currentlyConnected) {
              print("[OBDImpl] Desconexión detectada por listener, limpiando...");
             _cleanupConnection();
          }
        }
      }, onError: (error) {
           print("[OBDImpl] Error en stream de estado de conexión: $error");
           _isConnectedController.add(false);
           _cleanupConnection();
      });

      // Intentar conectar
      await _device!.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      
      // Esperar a que nuestro BehaviorSubject indique conexión, con timeout
      print("[OBDImpl] Esperando confirmación de estado conectado...");
      await _isConnectedController.stream
          .where((isConnected) => isConnected == true)
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () {
              print("[OBDImpl] Timeout esperando estado conectado.");
              throw TimeoutException("Timeout esperando estado conectado");
          });

      print("[OBDImpl] Estado conectado confirmado.");

      // Doble check por si acaso hubo una desconexión inmediata después de la confirmación
      if (!isConnected) {
          throw Exception("La conexión falló o se perdió inmediatamente después de conectar.");
      }

      await _discoverOBDCharacteristics(_device!); 
      await _initializeOBDAdapter();
      print("[OBDImpl] Conexión y configuración completadas.");
      return true;

    } catch (e) {
      print("[OBDImpl] Error durante la conexión: $e");
      await disconnect(); // Asegura limpieza
      return false;
    } finally {
      _isConnecting = false;
    }
  }
  
  Future<List<BluetoothDevice>> _scanForOBDDevices() async {
    List<BluetoothDevice> devices = [];
    
    try {
      await FlutterBluePlus.startScan(
        timeout: _connectionTimeout,
        androidUsesFineLocation: false
      );
      
      await for (final result in FlutterBluePlus.scanResults.timeout(
        _connectionTimeout,
        onTimeout: (sink) => sink.close(),
      )) {
        for (final r in result) {
          final name = r.device.platformName.toUpperCase();
          if (name.isNotEmpty && (
              name.contains("OBD") || 
              name.contains("ELM") ||
              name.contains("OBDII"))) {
            devices.add(r.device);
          }
        }
      }
      
      await FlutterBluePlus.stopScan();
      return devices;
    } catch (e) {
      debugPrint("[OBDImpl] Error durante el escaneo: $e");
      await FlutterBluePlus.stopScan();
      return devices;
    }
  }
  
  BluetoothDevice? _findBestOBDDevice(List<BluetoothDevice> devices) {
    for (var device in devices) {
      final name = device.platformName.toUpperCase();
      if (name.contains("OBD") || name.contains("ELM")) {
        return device;
      }
    }
    return devices.isNotEmpty ? devices.first : null;
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        timeout: _connectionTimeout,
        autoConnect: false
      );
    } catch (e) {
      throw Exception("Error al conectar con el dispositivo: $e");
    }
  }
  
  Future<void> _discoverOBDCharacteristics(BluetoothDevice device) async {
    _txCharacteristic = null;
    _rxCharacteristic = null;

    try {
      List<BluetoothService> services = await device.discoverServices();
      print("[OBDImpl] Servicios descubiertos: ${services.length}");

      // Variables para guardar los candidatos ESPECÍFICOS
      BluetoothCharacteristic? fff1RxNotifyCandidate;
      BluetoothCharacteristic? fff2TxCandidate;
      BluetoothCharacteristic? ffe1CombinedCandidate;
      
      // Variables para fallback genérico (se buscarán DESPUÉS si falla lo específico)
      BluetoothCharacteristic? genericTxCandidate;
      BluetoothCharacteristic? genericRxNotifyCandidate;

      print("--- Inicio Búsqueda de Características Específicas (FFF1/FFF2/FFE1) --- ");
      for (BluetoothService service in services) {
        print("[OBDImpl] Servicio: ${service.uuid}");
        for (BluetoothCharacteristic char in service.characteristics) {
          bool canWrite = char.properties.write || char.properties.writeWithoutResponse;
          bool canNotify = char.properties.notify || char.properties.indicate;
          
          print("[OBDImpl]   -> Char: ${char.uuid}, canWrite: $canWrite, canNotify: $canNotify");

          // Buscar FFF2 TX - Usar comparación de Guid
          if (fff2TxCandidate == null && char.uuid == _fff2CharacteristicGuid && canWrite) {
             fff2TxCandidate = char; 
             print("[OBDImpl]   -> >> ASIGNADO Candidato Específico FFF2 TX: ${char.uuid}"); 
          }
          // Buscar FFF1 RX Notify - Usar comparación de Guid
          if (fff1RxNotifyCandidate == null && char.uuid == _fff1CharacteristicGuid && canNotify) {
             fff1RxNotifyCandidate = char; 
             print("[OBDImpl]   -> >> ASIGNADO Candidato Específico FFF1 RX Notify: ${char.uuid}"); 
          }
          // Buscar FFE1 Combinada - Usar comparación de Guid
          if (ffe1CombinedCandidate == null && char.uuid == _ffe1CharacteristicGuid && canWrite && canNotify) {
             ffe1CombinedCandidate = char; 
             print("[OBDImpl]   -> Candidato Específico FFE1 Combinado encontrado: ${char.uuid}"); 
          }
        }
      }
      print("--- Fin Búsqueda de Características Específicas --- ");

      // --- Lógica de Selección Priorizada (Específicos primero) ---
      print("--- Inicio Selección de Características --- ");
      bool specificFound = false;
      // Prioridad 1: Par FFF1 (Notify) + FFF2 (Write)
      if (fff1RxNotifyCandidate != null && fff2TxCandidate != null) {
        print("[OBDImpl] Selección Prioridad 1: Usando FFF1 (RX Notify) y FFF2 (TX)");
        _rxCharacteristic = fff1RxNotifyCandidate;
        _txCharacteristic = fff2TxCandidate;
        specificFound = true;
      }
      // Prioridad 2: FFE1 Combinada (Write+Notify)
      else if (ffe1CombinedCandidate != null) {
        print("[OBDImpl] Selección Prioridad 2: Usando FFE1 Combinada (TX/RX)");
        _rxCharacteristic = ffe1CombinedCandidate;
        _txCharacteristic = ffe1CombinedCandidate;
        specificFound = true;
      }
      
      // --- Fallback a Genéricos (SOLO si no se encontraron específicos) ---
      if (!specificFound) {
           print("[OBDImpl] No se encontró combinación específica FFF1/2 o FFE1. Buscando genéricas...");
           for (BluetoothService service in services) {
              for (BluetoothCharacteristic char in service.characteristics) {
                  // Comparar Guid para ignorar 2A00
                  if (char.uuid == _deviceNameCharacteristicGuid) continue; 
                  
                  bool canWrite = char.properties.write || char.properties.writeWithoutResponse;
                  bool canNotify = char.properties.notify || char.properties.indicate;
                  
                  // Buscar TX Genérica (si aún no la tenemos)
                  if (genericTxCandidate == null && canWrite) {
                      genericTxCandidate = char;
                      print("[OBDImpl]   -> Candidato TX Genérico encontrado: ${char.uuid}");
                  }
                  // Buscar RX Notify Genérica (si aún no la tenemos)
                   if (genericRxNotifyCandidate == null && canNotify) {
                      genericRxNotifyCandidate = char;
                      print("[OBDImpl]   -> Candidato RX Notify Genérico encontrado: ${char.uuid}");
                  }
              }
           }
           
           // Usar genéricas si se encontraron ambas
           if (genericTxCandidate != null && genericRxNotifyCandidate != null) {
               print("[OBDImpl] Selección Prioridad 3 (Fallback): Usando TX Genérico (${genericTxCandidate!.uuid}) y RX Notify Genérico (${genericRxNotifyCandidate!.uuid})");
               _rxCharacteristic = genericRxNotifyCandidate;
               _txCharacteristic = genericTxCandidate;
           } else {
               print("[OBDImpl] Error Crítico: No se encontró combinación TX/RX adecuada (ni específica ni genérica).");
               throw Exception("No se encontraron características TX/RX adecuadas.");
           }
      }
      
      print("--- Fin Selección de Características --- ");
      print("[OBDImpl] TX Final Seleccionada: ${_txCharacteristic?.uuid}");
      print("[OBDImpl] RX Final Seleccionada: ${_rxCharacteristic?.uuid}");

      // Configurar notificaciones solo si RX las tiene y fue seleccionada
      if (_rxCharacteristic != null && (_rxCharacteristic!.properties.notify || _rxCharacteristic!.properties.indicate)) {
          print("[OBDImpl] Configurando notificaciones para RX: ${_rxCharacteristic!.uuid}");
          await _setupNotifications(_rxCharacteristic!);
      } else if (_rxCharacteristic != null && _rxCharacteristic!.properties.read) {
          print("[OBDImpl] La característica RX (${_rxCharacteristic!.uuid}) solo tiene READ. No se configuran notificaciones.");
      } else {
           print("[OBDImpl] La característica RX (${_rxCharacteristic?.uuid}) no es válida o no tiene Notify/Read.");
      }

    } catch (e) {
      print("[OBDImpl] Error durante el descubrimiento/selección de características: $e");
      rethrow; 
    }
  }
  
  Future<void> _setupNotifications(BluetoothCharacteristic characteristic) async {
    if (!characteristic.properties.notify && !characteristic.properties.indicate) {
      print("[OBDImpl] Error: Intento de configurar notificaciones en característica sin esa propiedad.");
      return;
    }
    try {
      await characteristic.setNotifyValue(true);
      _characteristicSubscription = characteristic.lastValueStream.listen(
        _handleResponse,
        onError: (e) {
             print("[OBDImpl] Error en stream de característica RX: $e");
             // Considerar reintentar o limpiar conexión
             disconnect();
        }
      );
      print("[OBDImpl] Notificaciones habilitadas para ${characteristic.uuid}");
    } catch (e) {
      print("[OBDImpl] Error al habilitar notificaciones para ${characteristic.uuid}: $e");
      throw Exception("Error al configurar notificaciones: $e");
    }
  }
  
  void _handleResponse(List<int> data) {
    // Decodificar con precaución, puede haber datos binarios o malformados
    String responseChunk;
    try {
      responseChunk = utf8.decode(data, allowMalformed: true);
    } catch (e) {
      print("[OBDImpl] Error decodificando datos recibidos: $e. Datos (hex): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}");
      responseChunk = ""; // Ignorar chunk inválido
    }
    
    // Añadir al buffer existente
    String currentBuffer = _responseBuffer.value + responseChunk;
    // print("[OBDImpl] Buffer: $currentBuffer"); // Log buffer detallado

    // Buscar el delimitador OBD '>'
    if (currentBuffer.contains('>')) {
      // Dividir por el delimitador. Puede haber múltiples respuestas en el buffer.
      var responses = currentBuffer.split('>');
      // La última parte podría ser incompleta, la guardamos para la próxima vez
      currentBuffer = responses.removeLast(); 
      
      for (var fullResponse in responses) {
        if (fullResponse.trim().isNotEmpty) {
          final cleanedResponse = _cleanResponse(fullResponse + '>'); // Añadir > para que _cleanResponse funcione
          print("[OBDImpl] Respuesta completa recibida: $cleanedResponse");
          // Intentar completar el completer del comando si existe
          if (_commandCompleter != null && !_commandCompleter!.isCompleted) {
            _commandTimeoutTimer?.cancel(); // Cancelar timeout ya que recibimos respuesta
            _commandCompleter!.complete(cleanedResponse);
            _commandCompleter = null; // Listo para el próximo comando
          }
        }
      }
    }
    // Guardar el buffer restante (puede ser vacío o una respuesta parcial)
    _responseBuffer.add(currentBuffer);
  }
  
  Future<String> _waitForResponse() async {
    if (_commandCompleter != null && !_commandCompleter!.isCompleted) {
      print("[OBDImpl] Advertencia: _waitForResponse llamado mientras un comando anterior aún está pendiente.");
      // Cancelar el completer anterior para evitar problemas
      _commandCompleter!.completeError(TimeoutException("Comando cancelado por uno nuevo"));
    }
    
    _commandCompleter = Completer<String>();
    
    // Iniciar timeout
    _commandTimeoutTimer?.cancel();
    _commandTimeoutTimer = Timer(_commandTimeout, () {
      if (_commandCompleter != null && !_commandCompleter!.isCompleted) {
        print("[OBDImpl] Timeout esperando respuesta.");
        _commandCompleter!.completeError(TimeoutException("No response received within timeout"));
        _commandCompleter = null;
      }
    });
    
    return _commandCompleter!.future;
  }
  
  String _cleanResponse(String response) {
    // Eliminar caracteres de control, saltos de línea, prompt OBD '>'
    // y mensajes comunes como "SEARCHING..."
    return response
        .replaceAll(RegExp(r'[\r\n\t]|SEARCHING\.\.\.|>| '), '') // Eliminar CR, LF, TAB, NULL, >, SEARCHING...
        .trim();
  }
  
  OBDData _parseResponse(String pid, String response) {
    // La respuesta ya viene limpia de _cleanResponse (sin espacios, sin >, etc.)
    // Ejemplos: "410C0C80", "410D00", "410563", "7F0112"

    // Validaciones iniciales
    if (response.contains("NODATA")) { // NO DATA puede venir sin espacios
       print("[OBDImpl] Respuesta NO DATA para $pid: '$response'");
       return _createErrorData(pid, "Sin datos");
    }
    if (response.startsWith("7F")) { // Código de error estándar OBD
       print("[OBDImpl] Respuesta de error OBD para $pid: '$response'");
       // Podrías intentar parsear el código de error aquí si quieres
       return _createErrorData(pid, "Error OBD: $response");
    }
    if (!response.startsWith("41")) { // Verificar modo 01 correcto
      print("[OBDImpl] Respuesta inválida (no empieza con 41) para $pid: '$response'");
      return _createErrorData(pid, "Respuesta inválida (modo incorrecto)");
    }
    if (response.length < 6) { // Mínimo 41 + PID (2) + Dato (2)
      print("[OBDImpl] Respuesta inválida (demasiado corta) para $pid: '$response'");
      return _createErrorData(pid, "Respuesta inválida (corta)");
    }

    // Verificar que el PID en la respuesta coincida con el solicitado
    final responsePid = response.substring(2, 4);
    if (responsePid != pid) {
       print("[OBDImpl] PID de respuesta ('$responsePid') no coincide con el solicitado ('$pid') en '$response'");
       return _createErrorData(pid, "PID no coincide");
    }

    // Extraer los bytes de datos hexadecimales (después de "41" y el PID)
    final dataHex = response.substring(4);
    List<String> dataBytesHex = [];
    try {
       for (int i = 0; i < dataHex.length; i += 2) {
         if (i + 1 < dataHex.length) {
           dataBytesHex.add(dataHex.substring(i, i + 2));
         }
       }
    } catch (e) {
        print("[OBDImpl] Error extrayendo bytes de '$dataHex' en respuesta '$response': $e");
        return _createErrorData(pid, "Error extrayendo bytes");
    }

     if (dataBytesHex.isEmpty) {
        print("[OBDImpl] No se encontraron bytes de datos para $pid en '$response'");
        return _createErrorData(pid, "Sin bytes de datos válidos");
     }


    // --- Parseo específico por PID --- 
    try {
       switch (pid) {
         case "05": // Temperatura del refrigerante (1 byte A) Formula: A-40
           final value = int.parse(dataBytesHex[0], radix: 16) - 40;
           return OBDData(pid: pid, value: value.toDouble(), unit: "°C", description: "Temperatura refrigerante");

         case "0C": // RPM (2 bytes A B) Formula: (256*A + B) / 4
           if (dataBytesHex.length < 2) return _createErrorData(pid, "Datos RPM incompletos");
           final value = (int.parse(dataBytesHex[0], radix: 16) * 256 + int.parse(dataBytesHex[1], radix: 16)) / 4;
           return OBDData(pid: pid, value: value, unit: "RPM", description: "RPM motor");

         case "0D": // Velocidad (1 byte A) Formula: A
           final value = int.parse(dataBytesHex[0], radix: 16);
           return OBDData(pid: pid, value: value.toDouble(), unit: "km/h", description: "Velocidad");

         case "42": // Voltaje módulo control (2 bytes A B) Formula: (256*A + B) / 1000
           if (dataBytesHex.length < 2) return _createErrorData(pid, "Datos Voltaje incompletos");
           final value = (int.parse(dataBytesHex[0], radix: 16) * 256 + int.parse(dataBytesHex[1], radix: 16)) / 1000.0;
           // Redondear a 2 decimales para mejor visualización
           final roundedValue = (value * 100).round() / 100.0;
           return OBDData(pid: pid, value: roundedValue, unit: "V", description: "Voltaje módulo control");

         default:
           print("[OBDImpl] PID $pid no implementado para parseo.");
           // Devolver los datos crudos si no sabemos parsearlos
           return OBDData(pid: pid, value: 0, unit: "hex", description: "Datos crudos: ${dataBytesHex.join('')}");
       }
     } catch (e) {
        print("[OBDImpl] Error parseando datos para $pid ('$response'): $e");
       return _createErrorData(pid, "Error al procesar datos: $e");
     }
   }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() async {
    // No implementado por ahora para simplificar
    return [];
  }
  
  @override
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    return _scanForOBDDevices();
  }
  
  @override
  Future<void> disconnect() async {
     print("[OBDImpl] Solicitud de desconexión...");
     final deviceToDisconnect = _device;
     _device = null; // Nullificar inmediatamente para prevenir reintentos
     _cleanupConnection(); // Limpiar suscripciones y estados

     if (deviceToDisconnect != null) {
       try {
         await deviceToDisconnect.disconnect();
         print("[OBDImpl] Desconexión FBP llamada.");
       } catch (e) {
         print("[OBDImpl] Error al desconectar FBP: $e");
       }
     } else {
        print("[OBDImpl] Ya desconectado o dispositivo nulo.");
     }
  }
  
  void _cleanupConnection() {
    print("[OBDImpl] Limpiando recursos de conexión...");
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _commandCompleter?.completeError("Desconectado");
    _commandCompleter = null;
    _commandTimeoutTimer?.cancel();
    _commandLock?.completeError(Exception("Conexión limpiada durante bloqueo"));
    _commandLock = null;
    _responseBuffer.add("");
    if (_isConnectedController.value) {
        _isConnectedController.add(false);
    }
    // _device = null; // No limpiar device aquí, se hace en disconnect
  }
  
  @override
  Stream<OBDData> getParameterData(String pid) async* {
    if (!isConnected) {
      yield _createErrorData(pid, "No hay conexión al dispositivo OBD");
      return;
    }
    
    if (_txCharacteristic == null) {
      yield _createErrorData(pid, "Característica de transmisión no encontrada");
      return;
    }

    // Si la característica RX solo tiene READ, la lectura manual no está implementada
    if (_rxCharacteristic != null && 
        !_rxCharacteristic!.properties.notify && 
        !_rxCharacteristic!.properties.indicate &&
        _rxCharacteristic!.properties.read) {
       yield _createErrorData(pid, "Recepción por READ no implementada");
       return;
    }
    
    // Esperar si hay un comando en curso
    while (_commandLock != null && !_commandLock!.isCompleted) {
        print("[OBDImpl] getParameterData($pid): Esperando bloqueo de comando anterior...");
        try {
            await _commandLock!.future;
        } catch (e) {
            print("[OBDImpl] getParameterData($pid): Bloqueo anterior completado con error: $e. Continuando...");
            // Ignorar el error del bloqueo anterior y proceder
        }
    }

    // Adquirir el bloqueo para este comando
    _commandLock = Completer<void>();
    print("[OBDImpl] getParameterData($pid): Bloqueo adquirido.");

    try {
      final command = "01$pid"; 
      print("[OBDImpl] Solicitando PID: $pid (Comando: $command)");
      final response = await _sendCommand(command);
      yield _parseResponse(pid, response); // Pasar PID original
    } catch (e) {
      print("[OBDImpl] Error en getParameterData para $pid: $e");
      yield _createErrorData(pid, "Error al obtener datos: ${e.toString()}");
    } finally {
        // Liberar el bloqueo
        if (!_commandLock!.isCompleted) {
           _commandLock!.complete();
        }
        _commandLock = null; // Permitir que el próximo comando se ejecute
        print("[OBDImpl] getParameterData($pid): Bloqueo liberado.");
    }
  }
  
  Future<String> _sendCommand(String command) async {
    if (!isConnected) throw Exception("No conectado");
    if (_txCharacteristic == null) throw Exception("Característica TX no válida");

    print("[OBDImpl] Intentando enviar comando: $command a ${_txCharacteristic!.uuid}");
    _responseBuffer.add(""); // Limpiar buffer antes de enviar
    
    try {
      final bytes = Uint8List.fromList(utf8.encode("$command\r\n"));
      
      // Determinar el método de escritura (preferir sin respuesta si está disponible)
      if (_txCharacteristic!.properties.writeWithoutResponse) {
        // print("[OBDImpl] Usando writeWithoutResponse para ${_txCharacteristic!.uuid}");
        await _txCharacteristic!.write(bytes, withoutResponse: true);
      } else if (_txCharacteristic!.properties.write) {
        // print("[OBDImpl] Usando write (con respuesta) para ${_txCharacteristic!.uuid}");
        await _txCharacteristic!.write(bytes, withoutResponse: false);
      } else {
        throw Exception("La característica TX seleccionada no soporta escritura.");
      }
      print("[OBDImpl] Comando '$command' enviado. Esperando respuesta...");
      
      // Esperar la respuesta
      final response = await _waitForResponse();
      return response; 
    } catch (e) {
      print("[OBDImpl] Error en _sendCommand($command): $e");
      throw Exception("Fallo al enviar/recibir comando $command: $e");
    }
  }
  
  Future<void> _initializeOBDAdapter() async {
    final commands = [
      "ATZ",     // Reset
      "ATE0",    // Echo off
      "ATL0",    // Linefeeds off
      "ATH0",    // Headers off
      "ATS0",    // Spaces off (puede que no sea necesario)
      "ATSP0",   // Auto protocol
    ];
    
    print("[OBDImpl] Inicializando adaptador OBD con comandos AT...");
    for (var cmd in commands) {
        // Esperar si hay un comando en curso (importante si la inicialización
        // ocurre mientras ya se están pidiendo PIDs)
        while (_commandLock != null && !_commandLock!.isCompleted) {
            print("[OBDImpl] _initializeOBDAdapter($cmd): Esperando bloqueo de comando anterior...");
             try {
                await _commandLock!.future;
             } catch (e) {
                print("[OBDImpl] _initializeOBDAdapter($cmd): Bloqueo anterior completado con error: $e. Continuando...");
             }
        }

        // Adquirir el bloqueo para este comando AT
        _commandLock = Completer<void>();
        print("[OBDImpl] _initializeOBDAdapter($cmd): Bloqueo adquirido.");

        try {
             // AÑADIR PEQUEÑA PAUSA antes de enviar comando AT
            await Future.delayed(const Duration(milliseconds: 150));
            // _sendCommand ahora se llama dentro del bloqueo
            final response = await _sendCommand(cmd);
            print("[OBDImpl] Respuesta a $cmd: $response");
        } catch (e) {
            print("[OBDImpl] Error/Timeout en comando $cmd: $e. Continuando...");
            if (cmd == "ATSP0") {
               print("[OBDImpl] Advertencia: Falló ATSP0 (Auto Protocol). La comunicación podría no funcionar.");
            }
        } finally {
            // Liberar el bloqueo
            if (!_commandLock!.isCompleted) {
               _commandLock!.complete();
            }
            _commandLock = null; // Permitir que el próximo comando se ejecute
             print("[OBDImpl] _initializeOBDAdapter($cmd): Bloqueo liberado.");
        }
    }
     print("[OBDImpl] Inicialización del adaptador OBD completada (o intentos realizados).");
  }

  OBDData _createErrorData(String pid, [String? error]) {
    return OBDData(
      pid: pid,
      value: 0,
      unit: "",
      description: error ?? "Error al obtener datos",
    );
  }
} 