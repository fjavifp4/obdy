import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:obdy/domain/entities/trip.dart';
import 'package:obdy/domain/repositories/trip_repository.dart';
import 'package:obdy/domain/repositories/vehicle_repository.dart';
import 'package:obdy/data/datasource/api_config.dart';
import 'package:obdy/data/models/trip_model.dart';
import 'package:obdy/data/models/gps_point_model.dart';

class TripRepositoryImpl implements TripRepository {
  final VehicleRepository _vehicleRepository;
  Trip? _currentTrip;
  String? _authToken;
  
  TripRepositoryImpl({
    required VehicleRepository vehicleRepository,
  }) : _vehicleRepository = vehicleRepository;
  
  @override
  Future<void> initialize([String? token]) async {
    try {
      // Si se proporciona un token, lo guardamos
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        
        // También lo guardamos en SharedPreferences para uso futuro
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }
      
      // Verificar si hay viajes activos mediante API
      final activeTrip = await getCurrentTrip();
      if (activeTrip != null) {
        _currentTrip = activeTrip;
      }
      
      // Verificar permisos de ubicación
      await _checkLocationPermission();
    } catch (e) {
      throw Exception('Error al inicializar el repositorio de viajes: $e');
    }
  }
  
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados');
    }
    
    // Verificar permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permisos de ubicación denegados');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Los permisos de ubicación están permanentemente denegados');
    }
  }
  
  @override
  Future<Trip> startTrip({required String vehicleId}) async {
    try {
      // Verificar si ya hay un viaje activo
      if (_currentTrip != null && _currentTrip!.isActive) {
        throw Exception('Ya hay un viaje activo en progreso');
      }
      
      // Verificar permisos de ubicación
      await _checkLocationPermission();
      
      // Obtener posición inicial
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high
        )
      );
      
      final initialPoint = GpsPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now()
      );
      
      // Enviar al backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode({
          'vehicle_id': vehicleId,
          'distance_in_km': 0.0,
          'fuel_consumption_liters': 0.0,
          'average_speed_kmh': 0.0,
          'duration_seconds': 0
        }),
      );
      
      if (response.statusCode == 201) {
        final tripData = json.decode(response.body);
        
        // Crear objeto Trip a partir de la respuesta usando el modelo
        final tripModel = TripModel.fromJson(tripData);
        // Añadir el punto GPS inicial que no viene en la respuesta
        final List<GpsPointModel> points = [GpsPointModel.fromEntity(initialPoint)];
        final tripWithPoint = TripModel(
          id: tripModel.id,
          vehicleId: tripModel.vehicleId,
          startTime: tripModel.startTime,
          endTime: tripModel.endTime,
          distanceInKm: tripModel.distanceInKm,
          isActive: tripModel.isActive,
          gpsPoints: points,
          fuelConsumptionLiters: tripModel.fuelConsumptionLiters,
          averageSpeedKmh: tripModel.averageSpeedKmh,
          durationSeconds: tripModel.durationSeconds
        );
        
        final trip = tripWithPoint.toEntity();
        
        // Guardar trip actual en memoria
        _currentTrip = trip;
        
        // Añadir el punto GPS al viaje en el backend
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/${trip.id}/gps-point'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _getToken()}',
          },
          body: json.encode({
            'latitude': initialPoint.latitude,
            'longitude': initialPoint.longitude,
            'timestamp': initialPoint.timestamp.toIso8601String()
          }),
        );
      
        return trip;
      } else {
        throw Exception('Error al crear el viaje en el servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al iniciar viaje: $e');
    }
  }
  
  @override
  Future<Trip> endTrip({required String tripId}) async {
    try {
      // Verificar si hay un viaje activo
      if (_currentTrip == null || _currentTrip!.id != tripId) {
        final currentTrip = await getCurrentTrip();
        if (currentTrip != null) {
          _currentTrip = currentTrip;
        } else {
          throw Exception('No se encontró el viaje con ID: $tripId');
        }
      }
      
      if (!_currentTrip!.isActive) {
        throw Exception('El viaje ya está finalizado');
      }
      
      // Obtener tiempo de finalización
      final endTime = DateTime.now();
      final durationSeconds = endTime.difference(_currentTrip!.startTime).inSeconds;
      
      // Usar el nuevo endpoint específico para finalizar viajes
      print("[TripRepositoryImpl] Finalizando viaje: $tripId");
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      
      if (response.statusCode != 200) {
        print("[TripRepositoryImpl] Error al finalizar el viaje en el servidor: ${response.statusCode}, ${response.body}");
        throw Exception('Error al finalizar el viaje en el servidor: ${response.statusCode}');
      }
      
      final tripData = json.decode(response.body);
      
      // Crear objeto Trip a partir de la respuesta usando el modelo
      final tripModel = TripModel.fromJson(tripData);
      // Conservar los puntos GPS que ya teníamos
      final updatedTripModel = TripModel(
        id: tripModel.id,
        vehicleId: tripModel.vehicleId,
        startTime: tripModel.startTime,
        endTime: tripModel.endTime,
        distanceInKm: tripModel.distanceInKm,
        isActive: tripModel.isActive,
        gpsPoints: _currentTrip!.gpsPoints.map((p) => GpsPointModel.fromEntity(p)).toList(),
        fuelConsumptionLiters: tripModel.fuelConsumptionLiters,
        averageSpeedKmh: tripModel.averageSpeedKmh,
        durationSeconds: tripModel.durationSeconds
      );
      
      final finishedTrip = updatedTripModel.toEntity();
      
      // Verificar que realmente esté marcado como inactivo
      if (finishedTrip.isActive) {
        print("[TripRepositoryImpl] ADVERTENCIA: El viaje debería estar inactivo pero aún está activo");
      } else {
        print("[TripRepositoryImpl] Viaje finalizado exitosamente: ${finishedTrip.id}");
      }
      
      // Actualizar memoria local
      _currentTrip = null; // Asegurarse de que no haya viaje activo en memoria
      
      return finishedTrip;
    } catch (e) {
      print("[TripRepositoryImpl] ERROR al finalizar viaje: $e");
      throw Exception('Error al finalizar viaje: $e');
    }
  }
  
  @override
  Future<Trip> updateTripDistance({
    required String tripId,
    required double distanceInKm,
    required GpsPoint newPoint,
    List<GpsPoint>? batchPoints,
  }) async {
    try {
      // Verificar si hay un viaje activo
      if (_currentTrip == null || _currentTrip!.id != tripId) {
        final currentTrip = await getCurrentTrip();
        if (currentTrip != null) {
          _currentTrip = currentTrip;
        } else {
          throw Exception('No se encontró el viaje con ID: $tripId');
        }
      }
      
      if (!_currentTrip!.isActive) {
        throw Exception('No se puede actualizar un viaje finalizado');
      }
      
      // Calcular duración actual
      final currentDuration = DateTime.now().difference(_currentTrip!.startTime).inSeconds;
      
      // Estimar la velocidad media
      double avgSpeed = 0;
      if (currentDuration > 0) {
        // Convertir duración a horas
        double hours = currentDuration / 3600;
        // Calcular la velocidad media en km/h
        avgSpeed = (_currentTrip!.distanceInKm + distanceInKm) / hours;
      }
      
      // Procesar puntos GPS - priorizar el lote si está disponible
      if (batchPoints != null && batchPoints.isNotEmpty) {
        // Usar el nuevo endpoint de batch para enviar todos los puntos de una vez
        await _sendGpsPointsBatch(tripId, batchPoints);
      } else {
        // Añadir el punto GPS individual al viaje en el backend
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-point'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _getToken()}',
          },
          body: json.encode({
            'latitude': newPoint.latitude,
            'longitude': newPoint.longitude,
            'timestamp': newPoint.timestamp.toIso8601String()
          }),
        );
      }
      
      // Actualizar la distancia y duración en el backend - Simplificar los campos enviados
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode({
          'distance_in_km': _currentTrip!.distanceInKm + distanceInKm,
          'average_speed_kmh': avgSpeed,
          'duration_seconds': currentDuration,
        }),
      );
      
      if (response.statusCode != 200) {
        print("[TripRepositoryImpl] Error al actualizar viaje: ${response.statusCode}, ${response.body}");
        throw Exception('Error al actualizar el viaje en el servidor: ${response.statusCode}, ${response.body}');
      }
      
      final tripData = json.decode(response.body);
      
      // Crear objeto Trip a partir de la respuesta usando el modelo
      final tripModel = TripModel.fromJson(tripData);
      
      // Añadir el nuevo punto GPS a la lista local
      final List<GpsPoint> updatedPoints = [..._currentTrip!.gpsPoints, newPoint];
      
      // Actualizar con los puntos GPS
      final updatedTripModel = TripModel(
        id: tripModel.id,
        vehicleId: tripModel.vehicleId,
        startTime: tripModel.startTime,
        endTime: tripModel.endTime,
        distanceInKm: tripModel.distanceInKm,
        isActive: tripModel.isActive,
        gpsPoints: updatedPoints.map((p) => GpsPointModel.fromEntity(p)).toList(),
        fuelConsumptionLiters: tripModel.fuelConsumptionLiters,
        averageSpeedKmh: tripModel.averageSpeedKmh,
        durationSeconds: tripModel.durationSeconds
      );
      
      final updatedTrip = updatedTripModel.toEntity();
      
      // Actualizar memoria local
      _currentTrip = updatedTrip;
      
      return updatedTrip;
    } catch (e) {
      print("[TripRepositoryImpl] ERROR al actualizar distancia: $e");
      throw Exception('Error al actualizar distancia del viaje: $e');
    }
  }
  
  @override
  Future<List<Trip>> getTripsForVehicle({required String vehicleId}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}?vehicle_id=$vehicleId'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error al obtener los viajes del servidor: ${response.statusCode}');
      }
      
      final List<dynamic> tripsData = json.decode(response.body);
      final List<Trip> trips = [];
      
      for (var tripData in tripsData) {
        final tripModel = TripModel.fromJson(tripData);
        trips.add(tripModel.toEntity());
      }
      
      return trips;
    } catch (e) {
      throw Exception('Error al obtener viajes: $e');
    }
  }
  
  @override
  Future<List<Trip>> getAllTrips() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error al obtener los viajes del servidor: ${response.statusCode}');
      }
      
      final List<dynamic> tripsData = json.decode(response.body);
      final List<Trip> trips = [];
      
      for (var tripData in tripsData) {
        final tripModel = TripModel.fromJson(tripData);
        trips.add(tripModel.toEntity());
      }
      
      return trips;
    } catch (e) {
      throw Exception('Error al obtener todos los viajes: $e');
    }
  }
  
  @override
  Future<Trip?> getCurrentTrip() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/active'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      
      // Si no hay viaje activo, el servidor devolverá 404
      if (response.statusCode == 404) {
        _currentTrip = null;
        return null;
      }
      
      if (response.statusCode != 200) {
        throw Exception('Error al obtener el viaje activo del servidor: ${response.statusCode}');
      }
      
      final tripData = json.decode(response.body);
      
      // Crear objeto Trip a partir de la respuesta usando el modelo
      final tripModel = TripModel.fromJson(tripData);
      _currentTrip = tripModel.toEntity();
      
      return _currentTrip;
    } catch (e) {
      // Si el error es de conexión o similar, intentamos usar datos en caché
      if (_currentTrip != null && _currentTrip!.isActive) {
        return _currentTrip;
      }
      
      throw Exception('Error al obtener el viaje actual: $e');
    }
  }
  
  @override
  Future<double> getTotalDistanceForVehicle({required String vehicleId}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/vehicle/$vehicleId/stats'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error al obtener estadísticas del vehículo: ${response.statusCode}');
      }
      
      final statsData = json.decode(response.body);
      return statsData['total_distance_km'].toDouble();
    } catch (e) {
      throw Exception('Error al calcular la distancia total: $e');
    }
  }
  
  @override
  Future<bool> updateMaintenanceRecordDistance({
    required String vehicleId,
    required String maintenanceRecordId,
    required double additionalDistance,
  }) async {
    try {
      // Esta funcionalidad ahora se maneja automáticamente en el backend
      // cuando se finaliza un viaje, pero podemos implementarla aquí para
      // actualizaciones manuales si es necesario
      
      // Utilizar el VehicleRepository para obtener y actualizar el registro de mantenimiento
      final vehicles = await _vehicleRepository.getVehicles();
      
      if (vehicles.isEmpty) {
        throw Exception('No se encontraron vehículos');
      }
      
      try {
        final vehicle = vehicles.firstWhere(
          (v) => v.id == vehicleId,
          orElse: () => throw Exception('Vehículo no encontrado'),
        );
        
        final maintenanceRecord = vehicle.maintenanceRecords.firstWhere(
          (record) => record.id == maintenanceRecordId,
          orElse: () => throw Exception('Registro de mantenimiento no encontrado'),
        );
        
        // Crear un mapa con los datos actualizados del registro
        final Map<String, dynamic> updatedRecordData = {
          'id': maintenanceRecord.id,
          'type': maintenanceRecord.type,
          'last_change_km': maintenanceRecord.lastChangeKM,
          'recommended_interval_km': maintenanceRecord.recommendedIntervalKM,
          'next_change_km': maintenanceRecord.nextChangeKM,
          'last_change_date': maintenanceRecord.lastChangeDate.toIso8601String(),
          'notes': maintenanceRecord.notes,
          'km_since_last_change': maintenanceRecord.kmSinceLastChange + additionalDistance,
        };
        
        // Actualizar el registro de mantenimiento
        await _vehicleRepository.updateMaintenanceRecord(vehicleId, updatedRecordData);
        
        return true;
      } catch (e) {
        throw Exception('Error al actualizar el registro: ${e.toString()}');
      }
    } catch (e) {
      throw Exception('Error al actualizar la distancia del registro de mantenimiento: $e');
    }
  }
  
  // Método para enviar un lote de puntos GPS al backend
  Future<bool> _sendGpsPointsBatch(String tripId, List<GpsPoint> points) async {
    try {
      if (points.isEmpty) {
        return true; // No hay puntos para enviar
      }
      
      // DEBUG: Imprimir detalles de los puntos que estamos enviando
      print("[TripRepositoryImpl] Enviando ${points.length} puntos GPS en lote:");
      for (int i = 0; i < points.length; i++) {
        print("[TripRepositoryImpl] Punto $i: lat=${points[i].latitude}, lon=${points[i].longitude}, time=${points[i].timestamp}");
      }
      
      // Preparar la lista de puntos en formato JSON
      final List<Map<String, dynamic>> pointsData = points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': point.timestamp.toIso8601String()
      }).toList();
      
      // Enviar al endpoint batch
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-points/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode(pointsData),
      );
      
      if (response.statusCode == 200) {
        print("[TripRepositoryImpl] Puntos GPS enviados en lote exitosamente: ${points.length}");
        return true;
      } else {
        print("[TripRepositoryImpl] Error al enviar puntos GPS en lote: ${response.statusCode}, ${response.body}");
        
        // Si el endpoint batch falló, intentar enviar los puntos uno por uno como fallback
        print("[TripRepositoryImpl] Intentando enviar puntos individualmente como fallback");
        bool allSuccess = true;
        
        for (var point in points) {
          final singleResponse = await http.post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-point'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await _getToken()}',
            },
            body: json.encode({
              'latitude': point.latitude,
              'longitude': point.longitude,
              'timestamp': point.timestamp.toIso8601String()
            }),
          );
          
          if (singleResponse.statusCode != 200) {
            print("[TripRepositoryImpl] Error enviando un punto individual: ${singleResponse.statusCode}");
            allSuccess = false;
          }
        }
        
        return allSuccess;
      }
    } catch (e) {
      print("[TripRepositoryImpl] Excepción al enviar puntos GPS en lote: $e");
      return false;
    }
  }
  
  // Método para obtener el token de autenticación
  Future<String> _getToken() async {
    // Primero intentamos usar el token en memoria
    if (_authToken != null && _authToken!.isNotEmpty) {
      return _authToken!;
    }
    
    // Si no está en memoria, intentamos obtenerlo de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('No se encontró el token de autenticación');
    }
    
    // Guardamos en memoria para uso futuro
    _authToken = token;
    return token;
  }
  
  @override
  Future<void> sendGpsPoint(String tripId, GpsPoint point) async {
    try {
      if (_currentTrip == null || _currentTrip!.id != tripId) {
        throw Exception('No hay un viaje activo con el ID proporcionado');
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-point'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode({
          'latitude': point.latitude,
          'longitude': point.longitude,
          'timestamp': point.timestamp.toIso8601String()
        }),
      );
      
      if (response.statusCode != 201) {
        throw Exception('Error al enviar punto GPS: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al enviar punto GPS: $e');
    }
  }
  
  @override
  Future<void> sendGpsPointsBatch(String tripId, List<GpsPoint> points) async {
    try {
      // No hacer nada si no hay puntos
      if (points.isEmpty) {
        print("[TripRepositoryImpl] No hay puntos GPS para enviar");
        return;
      }
      
      print("[TripRepositoryImpl] Enviando ${points.length} puntos GPS en lote para el viaje: $tripId");
      
      // Convertir puntos a JSON
      final List<Map<String, dynamic>> pointsJson = points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': point.timestamp.toIso8601String(),
      }).toList();
      
      print("[TripRepositoryImpl] Detalle de puntos a enviar: $pointsJson");
      
      // Verificar si el backend soporta envío en lote
      final hasBatchEndpoint = await _checkBatchEndpointExists(tripId);
      
      if (hasBatchEndpoint) {
        try {
          // Intentar enviar en lote
          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-points/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await _getToken()}',
            },
            body: json.encode(pointsJson),
          );
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            print("[TripRepositoryImpl] Puntos GPS enviados exitosamente en lote: ${response.statusCode}");
            return;
          } else {
            print("[TripRepositoryImpl] Error en respuesta batch: ${response.statusCode}, ${response.body}");
            throw Exception('Error en respuesta batch: ${response.statusCode}');
          }
        } catch (e) {
          print("[TripRepositoryImpl] Error en envío batch: $e, intentando envío individual");
          // Continuar con envío individual si falla el lote
        }
      }
      
      // Si no hay endpoint de lote disponible o falló el envío en lote, 
      // enviar puntos individualmente
      print("[TripRepositoryImpl] Enviando puntos GPS individualmente...");
      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        try {
          await sendGpsPoint(tripId, point);
          print("[TripRepositoryImpl] Punto ${i+1}/${points.length} enviado: lat=${point.latitude}, lon=${point.longitude}");
        } catch (e) {
          print("[TripRepositoryImpl] Error enviando punto ${i+1}/${points.length}: $e");
          // Continuar con el siguiente punto
        }
      }
    } catch (e) {
      print("[TripRepositoryImpl] Excepción general en sendGpsPointsBatch: $e");
      throw Exception('Error al enviar puntos GPS: $e');
    }
  }
  
  // Método para verificar si el endpoint de lotes existe en el backend
  Future<bool> _checkBatchEndpointExists(String tripId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId/gps-points/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode([]), // Enviar array vacío para verificar el endpoint
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("[TripRepositoryImpl] El endpoint de lotes no está disponible: $e");
      return false;
    }
  }
  
  @override
  Future<Trip> updatePeriodicTrip({
    required String tripId,
    required List<GpsPoint> batchPoints,
    required double totalDistance,
    required double totalFuelConsumed,
    required double averageSpeed,
    required int durationSeconds,
  }) async {
    try {
      // Verificar si el viaje activo local coincide
      if (_currentTrip == null || _currentTrip!.id != tripId) {
        final currentActive = await getCurrentTrip();
        if (currentActive == null || currentActive.id != tripId) {
          throw Exception('Viaje activo local no coincide o no se encontró.');
        }
        _currentTrip = currentActive;
      }
      
      if (!_currentTrip!.isActive) {
        throw Exception('No se puede actualizar periódicamente un viaje finalizado.');
      }
      
      // Preparar los datos de actualización
      final updateData = {
        'distance_in_km': totalDistance,
        'fuel_consumption_liters': totalFuelConsumed,
        'average_speed_kmh': averageSpeed,
        'duration_seconds': durationSeconds,
        'is_active': true,
      };
      
      // Si hay puntos GPS, añadirlos a la actualización
      if (batchPoints.isNotEmpty) {
        updateData['gps_points'] = batchPoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'timestamp': point.timestamp.toIso8601String()
        }).toList();
      }
      
      print("[TripRepositoryImpl] Actualizando periódicamente trip $tripId con: $updateData");
      
      // Enviar una sola petición PUT con todos los datos
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode(updateData),
      );
      
      if (response.statusCode != 200) {
        print("[TripRepositoryImpl] Error en actualización periódica: ${response.statusCode}, ${response.body}");
        throw Exception('Error al actualizar periódicamente el viaje en el servidor: ${response.statusCode}');
      }
      
      final tripData = json.decode(response.body);
      final tripModel = TripModel.fromJson(tripData);
      
      // Actualizar puntos locales
      if (batchPoints.isNotEmpty) {
        _currentTrip = _currentTrip!.copyWith(gpsPoints: [..._currentTrip!.gpsPoints, ...batchPoints]);
      }
      
      // Crear entidad actualizada
      final updatedTrip = tripModel.toEntity().copyWith(gpsPoints: _currentTrip!.gpsPoints);
      
      // Actualizar memoria local
      _currentTrip = updatedTrip;
      
      return updatedTrip;
      
    } catch (e) {
      print("[TripRepositoryImpl] ERROR en updatePeriodicTrip: $e");
      throw Exception('Error en la actualización periódica del viaje: $e');
    }
  }
} 
