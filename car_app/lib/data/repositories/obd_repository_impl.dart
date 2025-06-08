import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:collection/collection.dart';

import 'package:obdy/domain/entities/obd_data.dart';
import 'package:obdy/domain/repositories/obd_repository.dart';

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
  
  // Lista de PIDs soportados cacheados
  List<String>? _cachedSupportedPids;
  
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
    final originalResponseForError = response; // Guardar para logs de error

    // Validaciones iniciales
    if (response.contains("NODATA")) { // NO DATA puede venir sin espacios
       print("[OBDImpl] Respuesta NO DATA para $pid: '$response'");
       return _createErrorData(pid, "Sin datos", originalResponseForError);
    }
    if (response.startsWith("7F")) { // Código de error estándar OBD
       print("[OBDImpl] Respuesta de error OBD para $pid: '$response'");
       // Manejo específico para error "Servicio no soportado" (0x12) en PID 42
       if (pid == "42" && response.contains("7F0112")) {
           return _createErrorData(pid, "No Soportado", originalResponseForError);
       }
       // Podrías intentar parsear el código de error aquí si quieres
       return _createErrorData(pid, "Error OBD", originalResponseForError);
    }
    // Manejo específico para PID 42 que a veces no es soportado pero queremos simularlo
    if (pid == "42" && !response.startsWith("41")) {
      print("[OBDImpl] Respuesta inválida para PID 42 ('$response'), asumiendo No Soportado y simulando.");
      // Devolver valor simulado si la respuesta no es válida para PID 42
      return _simulateVoltageData();
    }
    if (!response.startsWith("41")) { // Verificar modo 01 correcto
      print("[OBDImpl] Respuesta inválida (no empieza con 41) para $pid: '$response'");
      return _createErrorData(pid, "Respuesta inválida (modo)", originalResponseForError);
    }
    if (response.length < 6) { // Mínimo 41 + PID (2) + Dato (2)
      print("[OBDImpl] Respuesta inválida (demasiado corta) para $pid: '$response'");
      return _createErrorData(pid, "Respuesta inválida (corta)", originalResponseForError);
    }

    // Verificar que el PID en la respuesta coincida con el solicitado
    final responsePid = response.substring(2, 4);
    if (responsePid != pid) {
       print("[OBDImpl] PID de respuesta ('$responsePid') no coincide con el solicitado ('$pid') en '$response'");
       return _createErrorData(pid, "PID no coincide", originalResponseForError);
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
        print("[OBDImpl] Error extrayendo bytes de '$dataHex' en respuesta '$originalResponseForError': $e");
        return _createErrorData(pid, "Error extrayendo bytes", originalResponseForError);
    }

     if (dataBytesHex.isEmpty) {
        print("[OBDImpl] No se encontraron bytes de datos para $pid en '$response'");
        return _createErrorData(pid, "Sin bytes válidos", originalResponseForError);
     }


    // --- Parseo específico por PID --- 
    try {
       switch (pid) {
         case "05": // Temperatura del refrigerante (1 byte A) Formula: A-40
           final value = int.parse(dataBytesHex[0], radix: 16) - 40;
           return OBDData(pid: pid, value: value.toDouble(), unit: "°C", description: "Temperatura refrigerante");

         case "0C": // RPM (2 bytes A B) Formula: (256*A + B) / 4
           if (dataBytesHex.length < 2) return _createErrorData(pid, "Datos RPM incompletos", originalResponseForError);
           final value = (int.parse(dataBytesHex[0], radix: 16) * 256 + int.parse(dataBytesHex[1], radix: 16)) / 4;
           return OBDData(pid: pid, value: value, unit: "RPM", description: "RPM motor");

         case "0D": // Velocidad (1 byte A) Formula: A
           final value = int.parse(dataBytesHex[0], radix: 16);
           return OBDData(pid: pid, value: value.toDouble(), unit: "km/h", description: "Velocidad");

         case "42": // Voltaje módulo control (2 bytes A B) Formula: (256*A + B) / 1000
           if (dataBytesHex.length < 2) return _createErrorData(pid, "Datos Voltaje incompletos", originalResponseForError);
           final value = (int.parse(dataBytesHex[0], radix: 16) * 256 + int.parse(dataBytesHex[1], radix: 16)) / 1000.0;
           // Redondear a 2 decimales para mejor visualización
           final roundedValue = (value * 100).round() / 100.0;
           return OBDData(pid: pid, value: roundedValue, unit: "V", description: "Voltaje módulo control");
        
         case "5E": // Engine Fuel Rate (2 bytes A B) Formula: (256*A + B) / 20
           if (dataBytesHex.length < 2) return _createErrorData(pid, "Datos Fuel Rate incompletos", originalResponseForError);
           final value = (int.parse(dataBytesHex[0], radix: 16) * 256 + int.parse(dataBytesHex[1], radix: 16)) / 20.0;
           final roundedValue = (value * 10).round() / 10.0; // Redondear a 1 decimal
           return OBDData(pid: pid, value: roundedValue, unit: "L/h", description: "Consumo combustible");
        
      default:
           print("[OBDImpl] PID $pid no implementado para parseo.");
           // Devolver los datos crudos si no sabemos parsearlos
           return OBDData(pid: pid, value: 0, unit: "hex", description: "Datos crudos: ${dataBytesHex.join('')}");
       }
     } catch (e) {
        print("[OBDImpl] Error parseando datos para $pid ('$response'): $e");
       // Usar rawResponse aquí en lugar de response para que _createErrorData lo reciba
       return _createErrorData(pid, "Error al procesar datos: $e", originalResponseForError);
     }
   }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() async {
    if (!isConnected) {
      throw Exception("Dispositivo OBD no conectado.");
    }
    
    // El comando OBD para obtener los DTCs almacenados es '03'
    final String command = "03";
    
    try {
      final response = await _sendCommand(command);
      
      // Parsear la respuesta para extraer los DTCs
      return _parseDTCResponse(response);
      
    } catch (e) {
      print("[OBDImpl] Error al obtener códigos DTC: $e");
      throw Exception("Error al obtener los códigos DTC: $e");
    }
  }

  // Método auxiliar para parsear la respuesta del comando 03
  List<String> _parseDTCResponse(String response) {
    final List<String> dtcs = [];
    // Eliminar espacios y saltos de línea
    final cleanResponse = response.replaceAll(RegExp(r'[\s>]+'), ''); 
    
    // Buscar el patrón de respuesta del comando 03 (ej: 43...)
    final headerMatch = RegExp(r'^43').firstMatch(cleanResponse);
    if (headerMatch == null) {
      // Puede que no haya DTCs o la respuesta sea inesperada
      if (cleanResponse.contains("NODATA")) {
         print("[OBDImpl] No se encontraron DTCs almacenados.");
         return dtcs; // Lista vacía si no hay datos
      }
      print("[OBDImpl] Respuesta inesperada para el comando 03: $cleanResponse");
      return dtcs; // Devolver lista vacía en caso de respuesta no reconocida
    }

    // El resto de la cadena después de '43' contiene los DTCs codificados
    String dtcData = cleanResponse.substring(headerMatch.end);
    
    // Cada DTC ocupa 4 caracteres hexadecimales (2 bytes)
    for (int i = 0; i < dtcData.length; i += 4) {
      if (i + 4 <= dtcData.length) {
        final dtcBytes = dtcData.substring(i, i + 4);
        // Ignorar si son '0000' que a veces se usa como padding
        if (dtcBytes != '0000') { 
          final dtcCode = _decodeDTC(dtcBytes);
          if (dtcCode != null) {
            dtcs.add(dtcCode);
          }
        }
      }
    }
    
    print("[OBDImpl] DTCs parseados: $dtcs");
    return dtcs;
  }

  // Método auxiliar para decodificar un DTC de 2 bytes hexadecimales
  String? _decodeDTC(String hexBytes) {
      if (hexBytes.length != 4) return null;
      
      try {
        int firstByte = int.parse(hexBytes.substring(0, 2), radix: 16);
        
        String firstChar;
        // Determinar la primera letra basado en los dos primeros bits del primer byte
        int firstTwoBits = (firstByte & 0xC0) >> 6; // 11000000
        switch (firstTwoBits) {
            case 0: firstChar = 'P'; break; // Powertrain
            case 1: firstChar = 'C'; break; // Chassis
            case 2: firstChar = 'B'; break; // Body
            case 3: firstChar = 'U'; break; // Network
            default: return null; // Imposible
        }
        
        // Los siguientes dos bits determinan el segundo carácter (0-3)
        int secondTwoBits = (firstByte & 0x30) >> 4; // 00110000
        
        // El resto del primer byte y el segundo byte forman los 3 dígitos restantes
        String remainingDigits = (firstByte & 0x0F).toRadixString(16).toUpperCase() + // 00001111
                                 hexBytes.substring(2, 4).toUpperCase();
                                 
        return '$firstChar${secondTwoBits.toString()}${remainingDigits.padLeft(3, '0')}';
      } catch (e) {
        print("[OBDImpl] Error decodificando DTC '$hexBytes': $e");
        return null;
      }
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

    // Cancelar timer y completer de comando actual ANTES de liberar el lock
    _commandTimeoutTimer?.cancel();
    if (_commandCompleter != null && !_commandCompleter!.isCompleted) {
      // Usar try-catch en caso de que se complete casi simultáneamente por otra vía
      try {
         _commandCompleter!.completeError(Exception("Desconectado"));
      } catch (_) {}
    }
    _commandCompleter = null;

    // Completar el lock si existe y no está completo
    final lockToComplete = _commandLock; // Guardar referencia local
    if (lockToComplete != null && !lockToComplete.isCompleted) {
        try {
          lockToComplete.completeError(Exception("Conexión limpiada durante bloqueo"));
        } catch (_) {} // Ignorar si ya se completó por error
    }
    _commandLock = null; // Poner a null DESPUÉS de intentar completar

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
    final currentLock = _commandLock; // Guardar referencia local

    try {
      // TEST: Añadir pequeña pausa antes de solicitar PID 42
      if (pid == "42") {
          print("[OBDImpl] Añadiendo pequeña pausa antes de solicitar PID 42...");
          await Future.delayed(const Duration(milliseconds: 50));
      }

      final command = "01$pid"; 
      print("[OBDImpl] Solicitando PID: $pid (Comando: $command)");
      final response = await _sendCommand(command);
      yield _parseResponse(pid, response); // Pasar PID original
    } catch (e) {
      print("[OBDImpl] Error en getParameterData para $pid: $e");
      yield _createErrorData(pid, "Error al obtener datos: ${e.toString()}");
    } finally {
        // Liberar el bloqueo usando la referencia local
        if (currentLock != null && !currentLock.isCompleted) {
            try {
                currentLock.complete();
            } catch (e) {
                 print("[OBDImpl] Error (ignorado) al completar lock local para $pid: $e");
            }
        }
        // Solo poner a null el lock global si ES el que acabamos de completar
        if (identical(_commandLock, currentLock)) {
             _commandLock = null;
        }
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

  OBDData _createErrorData(String pid, [String? error, String? rawResponse]) {
    String description = error ?? "Error al obtener datos";
    if (rawResponse != null && rawResponse.isNotEmpty) {
       description += " (Raw: $rawResponse)";
    }
    // Si el error es "No Soportado" para PID 42, devolvemos el valor simulado
    if (pid == "42" && error == "No Soportado") {
        print("[OBDImpl] _createErrorData interceptó error 'No Soportado' para PID 42, devolviendo simulación.");
        return _simulateVoltageData(); 
    }
    
    return OBDData(
      pid: pid,
      value: 0,
      unit: "",
      description: description,
    );
  }

  OBDData _simulateVoltageData() {
    // En modo real, si el PID 42 no es soportado, devolvemos un valor realista estable.
    // En el mock, sí habrá fluctuación.
    final baseVoltage = 13.8; 
    final simulatedValue = baseVoltage + ((DateTime.now().microsecond % 10) / 50.0); // Fluctuación mínima (0.0 a 0.2 V)
    final roundedValue = (simulatedValue * 100).round() / 100.0; // Redondear a 2 decimales
    return OBDData(
      pid: "42", 
      value: roundedValue, 
      unit: "V", 
      description: "Voltaje (No Soportado - Fallback)", // Indicar que es fallback
    );
  }

  @override
  Future<List<String>> getSupportedPids() async {
    if (!isConnected) {
      throw Exception("No conectado para obtener PIDs soportados");
    }

    // Primero probar con protocolos específicos
    print("[OBDImpl] Solicitando configuración del protocolo OBD...");
    try {
      // Intentar establecer un protocolo específico para mejorar la compatibilidad
      await _sendCommand("ATSP6").timeout(const Duration(seconds: 3), onTimeout: () {
        print("[OBDImpl] Timeout al configurar protocolo");
        return "TIMEOUT";
      });
      // También podríamos intentar con "ATTP6" para modo automático
    } catch (e) {
      print("[OBDImpl] Error al configurar protocolo específico: $e");
      // Continuar con el proceso a pesar del error
    }

    // Forzar borrado de la caché de PIDs soportados
    _cachedSupportedPids = null;

    print("[OBDImpl] Solicitando PIDs soportados...");
    final Set<String> supportedPids = {};
    final List<String> pidQueries = ["00", "20", "40", "60", "80", "A0", "C0"];

    // Añadir PID 1C manualmente para verificar versión de OBD
    try {
      final response = await _sendCommand("011C").timeout(const Duration(seconds: 3), onTimeout: () {
        print("[OBDImpl] Timeout al verificar estándar OBD (PID 1C)");
        return "TIMEOUT";
      });
      
      if (response != "TIMEOUT" && response.startsWith("411C")) {
        // Añadir 1C a la lista de PIDs soportados
        supportedPids.add("1C");
        
        // Interpretar el estándar OBD
        final dataHex = response.substring(4, 6);
        int standard = int.parse(dataHex, radix: 16);
        String standardName = _getOBDStandardName(standard);
        print("[OBDImpl] Estándar OBD detectado: $standardName (Código: $standard)");
      }
    } catch (e) {
      print("[OBDImpl] Error al verificar estándar OBD (PID 1C): $e");
    }

    // Establecer un límite de tiempo total para la operación
    final totalTimeoutTime = DateTime.now().add(const Duration(seconds: 8));

    for (final pidQuery in pidQueries) {
      // Verificar si hemos excedido el tiempo total
      if (DateTime.now().isAfter(totalTimeoutTime)) {
        print("[OBDImpl] Tiempo total excedido para búsqueda de PIDs, interrumpiendo");
        break;
      }
      
      try {
        // Esperar si hay un comando en curso (bloqueo)
        int waitAttempts = 0;
        while (_commandLock != null && !_commandLock!.isCompleted) {
          print("[OBDImpl] getSupportedPids($pidQuery): Esperando bloqueo...");
          waitAttempts++;
          if (waitAttempts > 3) {
            print("[OBDImpl] getSupportedPids($pidQuery): Demasiados intentos esperando bloqueo, saltando");
            break;
          }
          await _commandLock!.future.timeout(
            const Duration(milliseconds: 500), 
            onTimeout: () => print("[OBDImpl] Timeout esperando bloqueo de comando")
          );
        }
        
        if (waitAttempts > 3) continue; // Saltar este PID y continuar con el siguiente
        
        _commandLock = Completer<void>(); // Adquirir bloqueo
        print("[OBDImpl] getSupportedPids($pidQuery): Bloqueo adquirido.");
        final currentLock = _commandLock;

        String response;
        try {
           // AÑADIR PEQUEÑA PAUSA antes de enviar comando
           await Future.delayed(const Duration(milliseconds: 200));
           
           // Enviar comando con timeout
           response = await _sendCommand("01$pidQuery").timeout(
             const Duration(seconds: 3),
             onTimeout: () {
               print("[OBDImpl] Timeout al solicitar PIDs para 01$pidQuery");
               return "TIMEOUT";
             }
           );
           
           print("[OBDImpl] Respuesta para 01$pidQuery: $response");
        } finally {
            // Liberar el bloqueo
            if (currentLock != null && !currentLock.isCompleted) {
               try { currentLock.complete(); } catch (_) {} 
            }
            if (identical(_commandLock, currentLock)) { _commandLock = null; }
             print("[OBDImpl] getSupportedPids($pidQuery): Bloqueo liberado.");
        }
        
        // Si tuvimos timeout, pasar al siguiente PID
        if (response == "TIMEOUT") continue;
        
        // Parsear la respuesta (ej: "4100BE1FA813")
        final cleanedResponse = _cleanResponse(response);
        if (cleanedResponse.startsWith("41$pidQuery") && cleanedResponse.length >= 10) { // 41 + PID (2) + 4 bytes data (8)
          final dataHex = cleanedResponse.substring(4); // Obtener los 4 bytes (8 caracteres hex)
          final dataInt = int.parse(dataHex, radix: 16); // Convertir a entero
          final dataBinary = dataInt.toRadixString(2).padLeft(32, '0'); // Convertir a binario de 32 bits

          // Calcular el offset del PID basado en el query (00->01, 20->21, 40->41, etc.)
          final pidOffset = int.parse(pidQuery, radix: 16) + 1;

          for (int i = 0; i < 32; i++) {
            if (dataBinary[i] == '1') {
              final supportedPidNumber = pidOffset + i;
              final supportedPidHex = supportedPidNumber.toRadixString(16).toUpperCase().padLeft(2, '0');
              supportedPids.add(supportedPidHex);
            }
          }
          
          // Si el último bit (bit 31) es 1, significa que hay más PIDs en el siguiente rango
          if (dataBinary[31] == '0') {
            print("[OBDImpl] Último bit es 0 para 01$pidQuery, deteniendo búsqueda.");
            break; // No hay más PIDs que buscar
          }
        } else {
           print("[OBDImpl] Respuesta inválida o no soportada para 01$pidQuery: $cleanedResponse");
           // Si el primer PID (00) no es soportado, no podemos saber los demás
           if (pidQuery == "00") break;
        }
      } catch (e) {
        print("[OBDImpl] Error solicitando 01$pidQuery: $e. Continuando con el siguiente...");
        // Si falla la primera query, detener
        if (pidQuery == "00") {
           print("[OBDImpl] Falló la consulta inicial 0100, no se pueden determinar PIDs soportados.");
           break;
        }
      }
    }

    // Algunos PIDs comunes que a veces no se reportan correctamente pero suelen funcionar
    final commonPids = ["0C", "0D", "05", "42", "5E"];
    
    // Añadir PIDs específicos para probarlos manualmente
    for (final pid in commonPids) {
      // Verificar si hemos excedido el tiempo total
      if (DateTime.now().isAfter(totalTimeoutTime)) {
        print("[OBDImpl] Tiempo total excedido para prueba de PIDs comunes, interrumpiendo");
        break;
      }
      
      if (!supportedPids.contains(pid)) {
        try {
          print("[OBDImpl] Probando PID común $pid manualmente...");
          final response = await _sendCommand("01$pid").timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print("[OBDImpl] Timeout al probar PID común $pid");
              return "TIMEOUT";
            }
          );
          
          if (response != "TIMEOUT" && response.startsWith("41$pid")) {
            print("[OBDImpl] PID $pid funciona aunque no reportado como soportado, añadiendo");
            supportedPids.add(pid);
          }
        } catch (e) {
          print("[OBDImpl] Error probando PID $pid manualmente: $e");
        }
      }
    }

    _cachedSupportedPids = supportedPids.toList()..sort(); // Guardar en caché y ordenar
    print("[OBDImpl] PIDs soportados encontrados: ${_cachedSupportedPids!.length} -> ${_cachedSupportedPids}");
    return _cachedSupportedPids!;
  }
  
  // Método helper para convertir el código del estándar OBD a texto
  String _getOBDStandardName(int code) {
    switch (code) {
      case 1: return "OBD-II (California ARB)";
      case 2: return "OBD (Federal EPA)";
      case 3: return "OBD and OBD-II";
      case 4: return "OBD-I";
      case 5: return "No OBD";
      case 6: return "EOBD (Europe)";
      case 7: return "EOBD and OBD-II";
      case 8: return "EOBD and OBD";
      case 9: return "EOBD, OBD and OBD-II";
      case 10: return "JOBD (Japan)";
      case 11: return "JOBD and OBD-II";
      case 12: return "JOBD and EOBD";
      case 13: return "JOBD, EOBD, and OBD-II";
      case 14: return "EMD (Euro 4/5 heavy duty vehicles)";
      default: return "Desconocido ($code)";
    }
  }
} 
