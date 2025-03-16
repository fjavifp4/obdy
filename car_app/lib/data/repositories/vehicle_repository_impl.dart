import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/maintenance_record.dart';
import '../models/vehicle_model.dart';
import '../models/maintenance_record_model.dart';
import '../models/itv_model.dart';
import '../../config/core/utils/text_normalizer.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  String? _token;
  final String baseUrl = 'http://192.168.1.134:8000';

  @override
  Future<void> initialize(String token) async {
    _token = token;
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    try {
      
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> vehiclesJson = json.decode(response.body);
        final vehicles = vehiclesJson
            .map((json) => VehicleModel.fromJson(json).toEntity())
            .toList();
            
        return vehicles;
      } else {
        throw Exception('Error al obtener los vehículos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener los vehículos: $e');
    }
  }

  @override
  Future<Vehicle> addVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(vehicleData),
      );

      if (response.statusCode == 201) {
        return VehicleModel.fromJson(json.decode(response.body)).toEntity();
      } else {
        throw Exception('Error al crear el vehículo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<Vehicle> updateVehicle(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/vehicles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        return VehicleModel.fromJson(json.decode(response.body)).toEntity();
      } else {
        throw Exception('Error al actualizar el vehículo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<MaintenanceRecord> addMaintenanceRecord(
    String vehicleId,
    Map<String, dynamic> recordData,
  ) async {
    try {
      final formattedData = {
        'type': recordData['type'],
        'last_change_km': recordData['lastChangeKM'],
        'recommended_interval_km': recordData['recommendedIntervalKM'],
        'next_change_km': recordData['nextChangeKM'],
        'last_change_date': recordData['lastChangeDate'].toIso8601String(),
        'notes': recordData['notes'] ?? '',
        'km_since_last_change': recordData['kmSinceLastChange'] ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(formattedData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return MaintenanceRecordModel.fromJson(responseData).toEntity();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Error al añadir el registro de mantenimiento');
      }
    } catch (e) {
      throw Exception('Error al añadir el registro de mantenimiento: $e');
    }
  }

  @override
  Future<MaintenanceRecord> updateMaintenanceRecord(
    String vehicleId,
    Map<String, dynamic> recordData,
  ) async {
    try {
      final formattedData = {
        'id': recordData['id'],
        'type': recordData['type'],
        'last_change_km': recordData['lastChangeKM'],
        'recommended_interval_km': recordData['recommendedIntervalKM'],
        'next_change_km': recordData['nextChangeKM'],
        'last_change_date': recordData['lastChangeDate'].toIso8601String(),
        'notes': recordData['notes'] ?? '',
        'km_since_last_change': recordData['kmSinceLastChange'] ?? 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance/${recordData['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(formattedData),
      );

      if (response.statusCode == 200) {
        return MaintenanceRecordModel.fromJson(json.decode(response.body)).toEntity();
      } else {
        throw Exception('Error al actualizar el registro de mantenimiento');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<MaintenanceRecord> completeMaintenanceRecord(
    String vehicleId,
    String maintenanceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance/$maintenanceId/complete'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return MaintenanceRecordModel.fromJson(json.decode(response.body)).toEntity();
      } else {
        throw Exception('Error al completar el registro de mantenimiento');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> deleteVehicle(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vehicles/$id'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Error al eliminar el vehículo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> uploadManual(String vehicleId, List<int> fileBytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vehicles/$vehicleId/manual'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final response = await request.send();
      final responseStr = await response.stream.bytesToString();
      

      if (response.statusCode != 201) {
        final error = json.decode(responseStr);
        throw Exception(error['detail'] ?? 'Error al subir el manual');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<List<int>> downloadManual(String vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/$vehicleId/manual'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al descargar el manual');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<bool> checkManualExists(String vehicleId) async {
    try {
      
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/$vehicleId'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final vehicleJson = json.decode(response.body);
        final hasManual = vehicleJson['pdf_manual_grid_fs_id'] != null && 
                         vehicleJson['pdf_manual_grid_fs_id'].toString().isNotEmpty;
        return hasManual;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deleteMaintenanceRecord(String vehicleId, String maintenanceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance/$maintenanceId'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Error al eliminar el registro de mantenimiento');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> analyzeMaintenanceManual(String vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance-ai'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept-Charset': 'utf-8',
        },
      );

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(responseBody);
        
        List<Map<String, dynamic>> recommendations;
        
        // Intentar extraer recomendaciones según diferentes formatos de respuesta
        if (responseData is List) {
          // Si la respuesta es directamente una lista de recomendaciones
          recommendations = List<Map<String, dynamic>>.from(responseData);
        } else if (responseData['maintenance_recommendations'] != null) {
          // Si la respuesta tiene un campo 'maintenance_recommendations'
          recommendations = List<Map<String, dynamic>>.from(responseData['maintenance_recommendations']);
        } else if (responseData.containsKey('data') && responseData['data'] is List) {
          // Si la respuesta tiene un campo 'data' que es una lista
          recommendations = List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          // Respuesta no reconocida, intentar extraer cualquier lista
          final possibleListField = responseData.entries
              .firstWhere((entry) => entry.value is List, 
                        orElse: () => MapEntry('', []));
          
          if (possibleListField.value is List && possibleListField.value.isNotEmpty) {
            recommendations = List<Map<String, dynamic>>.from(possibleListField.value);
          } else {
            throw Exception('Formato de respuesta de IA no reconocido');
          }
        }

        // Normalizar y estandarizar las recomendaciones
        final normalizedRecommendations = recommendations.map((rec) {
          // Primero normalizar todo el mapa para corregir problemas de codificación
          final normalizedRec = TextNormalizer.normalizeMap(rec);
          
          // Luego estandarizar las claves para asegurar compatibilidad
          final standardizedRec = <String, dynamic>{};
          
          // Extraer tipo de mantenimiento buscando en diferentes claves posibles
          if (normalizedRec['tipo de mantenimiento'] != null) {
            standardizedRec['type'] = normalizedRec['tipo de mantenimiento'];
          } else if (normalizedRec['maintenance_type'] != null) {
            standardizedRec['type'] = normalizedRec['maintenance_type'];
          } else if (normalizedRec['title'] != null) {
            standardizedRec['type'] = normalizedRec['title'];
          } else if (normalizedRec['nombre'] != null) {
            standardizedRec['type'] = normalizedRec['nombre'];
          } else if (normalizedRec['type'] != null) {
            standardizedRec['type'] = normalizedRec['type'];
          } else {
            standardizedRec['type'] = 'Mantenimiento';
          }
          
          // Extraer intervalo recomendado
          if (normalizedRec['recommended_interval_km'] != null) {
            standardizedRec['recommended_interval_km'] = normalizedRec['recommended_interval_km'];
          } else if (normalizedRec['interval_km'] != null) {
            standardizedRec['recommended_interval_km'] = normalizedRec['interval_km'];
          } else if (normalizedRec['intervalo'] != null) {
            standardizedRec['recommended_interval_km'] = normalizedRec['intervalo'];
          } else {
            standardizedRec['recommended_interval_km'] = '10000';
          }
          
          // Extraer notas
          if (normalizedRec['notes'] != null) {
            standardizedRec['notes'] = normalizedRec['notes'];
          } else if (normalizedRec['notas'] != null) {
            standardizedRec['notes'] = normalizedRec['notas'];
          } else if (normalizedRec['description'] != null) {
            standardizedRec['notes'] = normalizedRec['description'];
          } else if (normalizedRec['descripcion'] != null) {
            standardizedRec['notes'] = normalizedRec['descripcion'];
          } else {
            standardizedRec['notes'] = '';
          }
          
          return standardizedRec;
        }).toList();
        
        return normalizedRecommendations;
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        final error = json.decode(errorBody);
        throw Exception(error['detail'] ?? 'Error al analizar el manual');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> deleteManual(String vehicleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/vehicles/$vehicleId/manual'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode != 204) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error al eliminar el manual');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> updateManual(String vehicleId, List<int> fileBytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vehicles/$vehicleId/manual/update'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final response = await request.send();
      final responseStr = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        final error = json.decode(responseStr);
        throw Exception(error['detail'] ?? 'Error al actualizar el manual');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  @override
  Future<void> updateItv(String vehicleId, DateTime itvDate) async {
    if (_token == null) {
      throw Exception('Token no inicializado');
    }

    final url = Uri.parse('$baseUrl/vehicles/$vehicleId/itv');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    final itvUpdate = ItvUpdateModel(itvDate: itvDate);
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(itvUpdate.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al actualizar la ITV: ${response.body}');
    }
  }

  @override
  Future<void> completeItv(String vehicleId) async {
    if (_token == null) {
      throw Exception('Token no inicializado');
    }

    final url = Uri.parse('$baseUrl/vehicles/$vehicleId/itv/complete');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    final response = await http.post(
      url,
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al marcar la ITV como completada: ${response.body}');
    }
  }
} 