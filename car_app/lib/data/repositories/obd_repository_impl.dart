import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:collection/collection.dart';
import 'package:math_expressions/math_expressions.dart';

import 'package:car_app/domain/entities/obd_data.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';

/// Implementación del repositorio OBD que utiliza flutter_blue_plus para
/// comunicarse con un adaptador OBD-II a través de Bluetooth.
class OBDRepositoryImpl implements OBDRepository {
  // UUID estándar para el servicio SPP (Serial Port Profile) en OBD-II
  final String _sppServiceUuid = "0000FFE0-0000-1000-8000-00805F9B34FB";
  final String _sppCharacteristicUuid = "0000FFE1-0000-1000-8000-00805F9B34FB";

  // Estado de la conexión
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _characteristicSubscription;
  
  // Control del estado
  final BehaviorSubject<bool> _isConnected = BehaviorSubject.seeded(false);
  final BehaviorSubject<String> _responseBuffer = BehaviorSubject.seeded("");
  final BehaviorSubject<Map<String, dynamic>> _lastResponse = BehaviorSubject.seeded({});

  // Modos OBD
  final Map<String, int> _obdModes = {
    'currentData': 0x01,      // Datos en tiempo real
    'freezeFrameData': 0x02,  // Datos de frame congelado
    'dtcs': 0x03,             // Códigos de diagnóstico almacenados
    'clearDtcs': 0x04,        // Limpiar códigos y valores almacenados
    'o2SensorTest': 0x05,     // Resultados de prueba del sensor de oxígeno
    'testResults': 0x06,      // Resultados de prueba de monitoreo no continuo
    'pendingDtcs': 0x07,      // Códigos de diagnóstico pendientes
    'controlOperation': 0x08, // Control de operación de componentes/sistemas
    'vehicleInfo': 0x09       // Solicitar información del vehículo
  };
  
  // Última solicitud 
  String _lastCommand = "";
  
  // Timeout para comandos
  final Duration _commandTimeout = const Duration(seconds: 5);
  
  // Constructor
  OBDRepositoryImpl();
  
  @override
  Future<void> initialize() async {
    if (!await FlutterBluePlus.isOn) {
      throw Exception("Bluetooth no está encendido");
    }
  }
  
  @override
  bool get isConnected => _isConnected.value;
  
  @override
  Future<bool> connect() async {
    try {
      // Inicializar el escáner Bluetooth
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Lista para almacenar dispositivos encontrados
      List<BluetoothDevice> devices = [];
      
      // Escuchar resultados del escaneo
      await for (final results in FlutterBluePlus.scanResults) {
        // Filtrar dispositivos OBD
        devices = results
            .where((r) => 
              r.device.name.isNotEmpty && (
              r.device.name.contains("OBD") || 
              r.device.name.contains("ELM") ||
              r.device.name.contains("BLE") ||
              r.device.name.contains("BT")))
            .map((r) => r.device)
            .toList();
        
        // Si encontramos al menos un dispositivo, detenemos el escaneo
        if (devices.isNotEmpty) {
          await FlutterBluePlus.stopScan();
          break;
        }
      }
      
      // Verificar después de un tiempo razonable si no encontramos ningún dispositivo
      await Future.delayed(const Duration(seconds: 12));
      if (devices.isEmpty) {
        await FlutterBluePlus.stopScan();
        throw Exception("No se encontraron dispositivos OBD compatibles");
      }
      
      // Conectar al primer dispositivo encontrado
      // En una aplicación real podrías permitir al usuario seleccionar el dispositivo
      _device = devices.first;
      await _device?.connect();
      
      // Descubrir servicios
      List<BluetoothService> services = await _device?.discoverServices() ?? [];
      
      // Encontrar el servicio SPP
      BluetoothService? sppService = services.firstWhereOrNull(
        (s) => s.uuid.toString() == _sppServiceUuid
      );
      
      if (sppService == null) {
        // Alternativa: buscar cualquier servicio que tenga características escribibles
        for (var service in services) {
          for (var char in service.characteristics) {
            if (char.properties.write || char.properties.writeWithoutResponse) {
              _characteristic = char;
              break;
            }
          }
          if (_characteristic != null) break;
        }
        
        if (_characteristic == null) {
          throw Exception("No se encontró un servicio compatible en el dispositivo OBD");
        }
      } else {
        // Encontrar la característica para enviar/recibir datos
        _characteristic = sppService.characteristics.firstWhereOrNull(
          (c) => c.uuid.toString() == _sppCharacteristicUuid && 
                 (c.properties.write || c.properties.writeWithoutResponse)
        );
        
        if (_characteristic == null) {
          throw Exception("No se encontró una característica compatible en el servicio SPP");
        }
      }
      
      // Suscribirse a las notificaciones si es posible
      if (_characteristic!.properties.notify) {
        await _characteristic!.setNotifyValue(true);
        _characteristicSubscription = _characteristic!.value.listen((value) {
          _handleResponse(String.fromCharCodes(value));
        });
      }
      
      // Marcar como conectado
      _isConnected.add(true);
      
      // Inicializar el adaptador OBD
      await _initializeOBDAdapter();
      
      return true;
    } catch (e) {
      await disconnect();
      throw Exception("Error al conectar con el dispositivo OBD: $e");
    }
  }
  
  @override
  Future<void> disconnect() async {
    try {
      // Cancelar la suscripción a características
      await _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      
      // Desconectar el dispositivo
      await _device?.disconnect();
      _device = null;
      _characteristic = null;
      
      // Actualizar estado
      _isConnected.add(false);
    } catch (e) {
      debugPrint("Error al desconectar: $e");
    }
  }
  
  @override
  Stream<OBDData> getParameterData(String pid) {
    if (!isConnected) {
      return Stream.error("No hay conexión al dispositivo OBD");
    }
    
    // Creo un stream que enviará el comando periódicamente y devolverá los resultados
    return Stream.periodic(const Duration(milliseconds: 500))
        .asyncMap((_) => _requestParameter(pid))
        .map((response) => _parseResponse(pid, response));
  }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() async {
    if (!isConnected) {
      throw Exception("No hay conexión al dispositivo OBD");
    }
    
    List<String> dtcCommands = [
      "03",       // DTCs almacenados
      "07",       // DTCs pendientes
      "0A",       // DTCs permanentes
    ];
    
    List<String> dtcCodes = [];
    
    for (String command in dtcCommands) {
      try {
        var response = await _sendCommand(command);
        dtcCodes.addAll(_parseDTCResponse(command, response));
      } catch (e) {
        debugPrint("Error al obtener DTCs con comando $command: $e");
      }
    }
    
    return dtcCodes;
  }
  
  // Métodos privados de ayuda
  
  /// Inicializa el adaptador OBD-II con los comandos AT necesarios
  Future<void> _initializeOBDAdapter() async {
    List<String> initCommands = [
      "ATZ",      // Reset
      "ATL0",     // Desactivar linefeeds
      "ATE0",     // Desactivar echo
      "ATH0",     // Desactivar headers
      "ATS0",     // Desactivar espacios
      "ATSP0",    // Auto protocolo
      "ATAT1",    // Timing adaptativo
      "ATST32",   // Timeout en milisegundos (32 * 4 = 128ms)
    ];
    
    for (String command in initCommands) {
      try {
        await _sendCommand(command);
      } catch (e) {
        debugPrint("Error en comando de inicialización $command: $e");
      }
    }
  }
  
  /// Envía un comando al adaptador OBD y espera la respuesta
  Future<String> _sendCommand(String command) async {
    if (!isConnected) {
      throw Exception("No hay conexión al dispositivo OBD");
    }
    
    // Limpiar buffer
    _responseBuffer.add("");
    _lastCommand = command;
    
    // Preparar el comando (añadir CR+LF)
    Uint8List bytes = Uint8List.fromList(utf8.encode("$command\r\n"));
    
    // Enviar el comando
    if (_characteristic!.properties.writeWithoutResponse) {
      await _characteristic!.write(bytes, withoutResponse: true);
    } else {
      await _characteristic!.write(bytes);
    }
    
    // Esperar respuesta o timeout
    String response = "";
    try {
      response = await _waitForResponse();
      return _cleanResponse(response);
    } catch (e) {
      throw Exception("Timeout o error al enviar comando $command: $e");
    }
  }
  
  /// Espera la respuesta completa del adaptador OBD
  Future<String> _waitForResponse() async {
    Completer<String> completer = Completer<String>();
    
    late StreamSubscription subscription;
    subscription = _responseBuffer.stream.listen((buffer) {
      // Verificamos si la respuesta está completa (termina con '>')
      if (buffer.contains('>')) {
        if (!completer.isCompleted) {
          completer.complete(buffer);
        }
        subscription.cancel();
      }
    });
    
    // Configurar timeout
    Future.delayed(_commandTimeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError("Timeout esperando respuesta");
      }
    });
    
    return completer.future;
  }
  
  /// Maneja las respuestas recibidas del adaptador
  void _handleResponse(String data) {
    String currentBuffer = _responseBuffer.value;
    currentBuffer += data;
    _responseBuffer.add(currentBuffer);
  }
  
  /// Limpia la respuesta quitando caracteres innecesarios
  String _cleanResponse(String response) {
    return response
        .replaceAll(_lastCommand, "")
        .replaceAll("\r", "")
        .replaceAll("\n", "")
        .replaceAll(">", "")
        .replaceAll("SEARCHING...", "")
        .trim();
  }
  
  /// Solicita un parámetro específico al OBD
  Future<String> _requestParameter(String pid) async {
    // Si pid es un comando AT, enviarlo directamente
    if (pid.startsWith("AT") || pid.startsWith("at")) {
      return _sendCommand(pid);
    }
    
    // En caso contrario, es un PID en modo 01 (datos actuales)
    String command = pid.contains(" ") ? pid : "01 $pid";
    return _sendCommand(command);
  }
  
  /// Convierte la respuesta en un objeto OBDData
  OBDData _parseResponse(String pid, String response) {
    if (response.contains("NO DATA") || response.isEmpty) {
      return OBDData(
        pid: pid,
        value: 0,
        unit: "",
        description: "Sin datos",
      );
    }
    
    // Si es un comando AT, procesarlo según corresponda
    if (pid.toUpperCase().startsWith("AT")) {
      return _parseATResponse(pid, response);
    }
    
    // Es un PID normal, procesar según el tipo
    try {
      return _processPIDResponse(pid, response);
    } catch (e) {
      return OBDData(
        pid: pid,
        value: 0,
        unit: "",
        description: "Error: ${e.toString()}",
      );
    }
  }
  
  /// Procesa un PID específico según su tipo
  OBDData _processPIDResponse(String pid, String response) {
    // Limpiar el pid para obtener solo el número (sin el modo)
    String pidNumber = pid.contains(" ") ? pid.split(" ").last : pid;
    
    // Obtener los bytes de respuesta en hexadecimal
    List<String> hexBytes = _extractHexBytes(response);
    
    // Procesar según el PID
    switch (pidNumber) {
      case "04": // Carga del motor
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16) * 100 / 255;
        return OBDData(
          pid: pid,
          value: value,
          unit: "%",
          description: "Carga del motor",
        );
        
      case "05": // Temperatura del refrigerante
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16) - 40;
        return OBDData(
          pid: pid,
          value: value,
          unit: "°C",
          description: "Temperatura del refrigerante",
        );
        
      case "0C": // RPM del motor
        if (hexBytes.length < 2) return _createErrorData(pid, "Datos insuficientes");
        double value = (int.parse(hexBytes[0], radix: 16) * 256 + int.parse(hexBytes[1], radix: 16)) / 4;
        return OBDData(
          pid: pid,
          value: value,
          unit: "RPM",
          description: "RPM del motor",
        );
        
      case "0D": // Velocidad del vehículo
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16).toDouble();
        return OBDData(
          pid: pid,
          value: value,
          unit: "km/h",
          description: "Velocidad",
        );
        
      case "0F": // Temperatura del aire de admisión
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16) - 40;
        return OBDData(
          pid: pid,
          value: value,
          unit: "°C",
          description: "Temperatura de aire de admisión",
        );
        
      case "10": // Flujo de aire MAF
        if (hexBytes.length < 2) return _createErrorData(pid, "Datos insuficientes");
        double value = (int.parse(hexBytes[0], radix: 16) * 256 + int.parse(hexBytes[1], radix: 16)) / 100;
        return OBDData(
          pid: pid,
          value: value,
          unit: "g/s",
          description: "Flujo de aire MAF",
        );
        
      case "11": // Posición del acelerador
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16) * 100 / 255;
        return OBDData(
          pid: pid,
          value: value,
          unit: "%",
          description: "Posición del acelerador",
        );
        
      case "0B": // Presión absoluta del colector
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos insuficientes");
        double value = int.parse(hexBytes[0], radix: 16).toDouble();
        return OBDData(
          pid: pid,
          value: value,
          unit: "kPa",
          description: "Presión del colector",
        );
        
      default:
        // Para PIDs no específicamente implementados, intentar devolver el primer byte como valor
        if (hexBytes.isEmpty) return _createErrorData(pid, "Datos desconocidos");
        double value = int.parse(hexBytes[0], radix: 16).toDouble();
        return OBDData(
          pid: pid,
          value: value,
          unit: "",
          description: _getPidName(pid),
        );
    }
  }
  
  /// Procesa respuesta de comandos AT
  OBDData _parseATResponse(String pid, String response) {
    switch (pid.toUpperCase()) {
      case "ATRV": // Voltaje de la batería
        double value = 0;
        try {
          // Intentar extraer un valor numérico (formato típico: 12.5V)
          String numericPart = response.replaceAll(RegExp(r'[^\d.]'), '');
          value = double.parse(numericPart);
        } catch (e) {
          return _createErrorData(pid, "Error al procesar voltaje");
        }
        
        return OBDData(
          pid: pid,
          value: value,
          unit: "V",
          description: "Voltaje de batería",
        );
        
      default:
        // Para otros comandos AT, devolver la respuesta como cadena
        return OBDData(
          pid: pid,
          value: 0,
          unit: "",
          description: "$pid: $response",
        );
    }
  }
  
  /// Extrae bytes de la respuesta en formato hexadecimal
  List<String> _extractHexBytes(String response) {
    // Quitar espacios y separar en pares de caracteres (bytes)
    String cleanedResponse = response.replaceAll(" ", "");
    List<String> bytes = [];
    
    // Si la respuesta tiene longitud impar, añadir un 0 al principio
    if (cleanedResponse.length % 2 != 0) {
      cleanedResponse = "0$cleanedResponse";
    }
    
    // Dividir en bytes (pares de caracteres)
    for (int i = 0; i < cleanedResponse.length; i += 2) {
      if (i + 2 <= cleanedResponse.length) {
        bytes.add(cleanedResponse.substring(i, i + 2));
      }
    }
    
    return bytes;
  }
  
  /// Parsea la respuesta de comandos de DTCs
  List<String> _parseDTCResponse(String command, String response) {
    List<String> dtcCodes = [];
    
    if (response.isEmpty || response.contains("NO DATA")) {
      return dtcCodes;
    }
    
    // Extraer bytes de la respuesta
    List<String> hexBytes = _extractHexBytes(response);
    
    // Si es comando 03, 07 o 0A (DTCs almacenados, pendientes o permanentes)
    if (command == "03" || command == "07" || command == "0A") {
      // Número de DTCs (primer byte)
      if (hexBytes.isEmpty) return dtcCodes;
      int numDtcs = int.parse(hexBytes[0], radix: 16);
      
      // Si no hay DTCs, retornar lista vacía
      if (numDtcs == 0) return dtcCodes;
      
      // Procesar los DTCs (cada DTC ocupa 2 bytes)
      for (int i = 0; i < numDtcs && (i*2 + 2) < hexBytes.length; i++) {
        int byteA = int.parse(hexBytes[i*2 + 1], radix: 16);
        int byteB = int.parse(hexBytes[i*2 + 2], radix: 16);
        
        String dtcCode = _decodeDTC(byteA, byteB);
        if (dtcCode.isNotEmpty && !dtcCodes.contains(dtcCode)) {
          dtcCodes.add(dtcCode);
        }
      }
    }
    
    return dtcCodes;
  }
  
  /// Decodifica un par de bytes en un código DTC
  String _decodeDTC(int byteA, int byteB) {
    // Primer caracter (tipo de DTC)
    String prefix = "";
    switch (byteA >> 6) {
      case 0: prefix = "P"; break; // Powertrain
      case 1: prefix = "C"; break; // Chassis
      case 2: prefix = "B"; break; // Body
      case 3: prefix = "U"; break; // Network
      default: return "";
    }
    
    // Segundo caracter (OEM/genérico)
    String secondChar = ((byteA >> 4) & 0x3) == 0 ? "0" : "1";
    
    // Tercer caracter
    String thirdChar = (byteA & 0xF).toRadixString(16).toUpperCase();
    
    // Cuarto y quinto caracteres
    String fourthAndFifth = byteB.toRadixString(16).toUpperCase().padLeft(2, '0');
    
    return "$prefix$secondChar$thirdChar$fourthAndFifth";
  }
  
  /// Crea un objeto OBDData para errores
  OBDData _createErrorData(String pid, String error) {
    return OBDData(
      pid: pid,
      value: 0,
      unit: "",
      description: "$error (PID: $pid)",
    );
  }
  
  /// Obtiene un nombre descriptivo para un PID
  String _getPidName(String pid) {
    String pidNumber = pid.contains(" ") ? pid.split(" ").last : pid;
    
    Map<String, String> pidNames = {
      "04": "Carga del motor",
      "05": "Temperatura del refrigerante",
      "0C": "RPM del motor",
      "0D": "Velocidad",
      "0F": "Temperatura de aire de admisión",
      "10": "Flujo de aire MAF",
      "11": "Posición del acelerador",
      "0B": "Presión del colector",
      // Añadir más PIDs según sea necesario
    };
    
    return pidNames[pidNumber] ?? "PID $pidNumber";
  }
  
  /// Calcula el consumo de combustible estimado en L/100km
  /// Requiere RPM (0C), MAF (10) y VSS (0D)
  Future<double> calculateFuelConsumption() async {
    if (!isConnected) {
      throw Exception("No hay conexión al dispositivo OBD");
    }
    
    // Obtener RPM
    String rpmResponse = await _requestParameter("0C");
    List<String> rpmHexBytes = _extractHexBytes(rpmResponse);
    if (rpmHexBytes.length < 2) return 0;
    double rpm = (int.parse(rpmHexBytes[0], radix: 16) * 256 + int.parse(rpmHexBytes[1], radix: 16)) / 4;
    
    // Obtener MAF (g/s)
    String mafResponse = await _requestParameter("10");
    List<String> mafHexBytes = _extractHexBytes(mafResponse);
    if (mafHexBytes.length < 2) return 0;
    double maf = (int.parse(mafHexBytes[0], radix: 16) * 256 + int.parse(mafHexBytes[1], radix: 16)) / 100;
    
    // Obtener velocidad (km/h)
    String speedResponse = await _requestParameter("0D");
    List<String> speedHexBytes = _extractHexBytes(speedResponse);
    if (speedHexBytes.isEmpty) return 0;
    double speed = int.parse(speedHexBytes[0], radix: 16).toDouble();
    
    // Si velocidad es 0, el consumo es infinito, devolver 0 para evitar división por cero
    if (speed < 1) return 0;
    
    // Calcular consumo: (MAF / 14.7 / 750) * 3600 * 100 / speed (L/100km)
    // 14.7 = relación aire/combustible para gasolina
    // 750 = densidad aproximada de la gasolina en g/L
    double consumption = (maf / 14.7 / 750) * 3600 * 100 / speed;
    
    return double.parse(consumption.toStringAsFixed(2));
  }
} 