import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/maintenance_record.dart';
import '../models/vehicle_model.dart';
import '../models/maintenance_record_model.dart';

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
      final response = await http.put(
        Uri.parse('$baseUrl/vehicles/$vehicleId/maintenance/${recordData['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(recordData),
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
} 