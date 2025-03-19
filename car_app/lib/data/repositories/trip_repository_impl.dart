import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:car_app/domain/entities/trip.dart';
import 'package:car_app/domain/repositories/trip_repository.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';
import 'package:car_app/data/datasource/api_config.dart';
import 'package:car_app/data/models/trip_model.dart';
import 'package:car_app/data/models/gps_point_model.dart';

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
      
      // Actualizar en el backend
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tripsEndpoint}/$tripId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: json.encode({
          'is_active': false,
          'end_time': endTime.toIso8601String(),
          'duration_seconds': durationSeconds,
        }),
      );
      
      if (response.statusCode != 200) {
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
      
      // Actualizar memoria local
      _currentTrip = finishedTrip;
      
      return finishedTrip;
    } catch (e) {
      throw Exception('Error al finalizar viaje: $e');
    }
  }
  
  @override
  Future<Trip> updateTripDistance({
    required String tripId,
    required double distanceInKm,
    required GpsPoint newPoint
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
      
      // Añadir el punto GPS al viaje en el backend
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
      
      // Actualizar la distancia y duración en el backend
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
        throw Exception('Error al actualizar el viaje en el servidor: ${response.statusCode}');
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
} 