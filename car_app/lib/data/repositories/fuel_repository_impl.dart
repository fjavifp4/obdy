import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'package:car_app/domain/repositories/fuel_repository.dart';
import 'package:car_app/data/models/fuel_station_model.dart';
import 'package:geolocator/geolocator.dart';

class FuelRepositoryImpl implements FuelRepository {
  String? _token;
  final String baseUrl = 'http://192.168.1.134:8000';

  @override
  Future<void> initialize(String token) async {
    _token = token;
  }
  
  @override
  Future<Either<Failure, Map<String, double>>> getGeneralFuelPrices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fuel/prices'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Either.right(Map<String, double>.from(jsonData['prices']));
      } else {
        return Either.left(ServerFailure('Error al obtener precios: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<FuelStation>>> getNearbyStations({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    String? fuelType,
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
      };
      
      if (fuelType != null) {
        queryParams['fuel_type'] = fuelType;
      }
      
      final uri = Uri.parse('$baseUrl/fuel/stations/nearby').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          // Asegurar que el encoding es correcto para caracteres especiales
          String responseBody = utf8.decode(response.bodyBytes);
          final Map<String, dynamic> data = json.decode(responseBody);
          
          final stationsList = data['stations'] as List? ?? [];
          
          final stations = stationsList
              .map((json) => FuelStationModel.fromJson(json as Map<String, dynamic>).toEntity())
              .toList();
          
          // Calcular distancias desde la ubicación actual
          for (var i = 0; i < stations.length; i++) {
            final station = stations[i];
            
            if (station.distance == null) {
              try {
                final distanceInMeters = Geolocator.distanceBetween(
                  latitude, 
                  longitude,
                  station.latitude, 
                  station.longitude,
                );
                
                // Convertir metros a kilómetros y actualizar la estación
                final distanceInKm = distanceInMeters / 1000;
                stations[i] = station.copyWith(distance: distanceInKm);
              } catch (e) {
                // Si hay un error al calcular la distancia, simplemente continuamos
                print('Error al calcular distancia: $e');
              }
            }
          }
          
          // Ordenar por distancia (las más cercanas primero)
          stations.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
              
          return Either.right(stations);
        } catch (e) {
          print('Error al procesar respuesta: $e');
          return Either.left(ServerFailure('Error al procesar respuesta: $e'));
        }
      } else {
        return Either.left(ServerFailure('Error al obtener estaciones: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<FuelStation>>> getFavoriteStations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fuel/stations/favorites'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          // Asegurar que el encoding es correcto para caracteres especiales
          String responseBody = utf8.decode(response.bodyBytes);
          final Map<String, dynamic> data = json.decode(responseBody);
          
          final stationsList = data['stations'] as List? ?? [];
          
          final stations = stationsList
              .map((json) => FuelStationModel.fromJson(json as Map<String, dynamic>).toEntity())
              .toList();
              
          return Either.right(stations);
        } catch (e) {
          print('Error al procesar respuesta: $e');
          return Either.left(ServerFailure('Error al procesar respuesta de favoritos: $e'));
        }
      } else {
        return Either.left(ServerFailure('Error al obtener favoritos: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> addFavoriteStation(String stationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fuel/stations/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({'station_id': stationId}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Either.right(true);
      } else {
        return Either.left(ServerFailure('Error al añadir favorito: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> removeFavoriteStation(String stationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/fuel/stations/favorites/$stationId'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return Either.right(true);
      } else {
        return Either.left(ServerFailure('Error al eliminar favorito: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, FuelStation>> getStationDetails(String stationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fuel/stations/$stationId'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        final stationJson = json.decode(response.body);
        final station = FuelStationModel.fromJson(stationJson).toEntity();
        return Either.right(station);
      } else {
        return Either.left(ServerFailure('Error al obtener detalles: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<FuelStation>>> searchStations(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fuel/stations/search').replace(
          queryParameters: {'query': query},
        ),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final stationsList = jsonData['stations'] as List;
        
        final stations = stationsList
            .map((json) => FuelStationModel.fromJson(json).toEntity())
            .toList();
            
        return Either.right(stations);
      } else {
        return Either.left(ServerFailure('Error al buscar estaciones: ${response.statusCode}'));
      }
    } catch (e) {
      return Either.left(ConnectionFailure('Error de conexión: $e'));
    }
  }
} 