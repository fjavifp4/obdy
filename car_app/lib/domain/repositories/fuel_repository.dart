import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import '../entities/fuel_station.dart';

abstract class FuelRepository {
  /// Inicializa el repositorio con el token de autenticación
  Future<void> initialize(String token);
  
  /// Obtiene los precios generales de combustible promediados a nivel nacional
  Future<Either<Failure, Map<String, double>>> getGeneralFuelPrices();
  
  /// Obtiene estaciones de servicio cercanas a una ubicación
  /// 
  /// [latitude] y [longitude] definen la ubicación central
  /// [radius] es el radio de búsqueda en kilómetros (por defecto 5km)
  /// [fuelType] filtra por un tipo específico de combustible (opcional)
  Future<Either<Failure, List<FuelStation>>> getNearbyStations({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    String? fuelType,
  });
  
  /// Obtiene las estaciones favoritas del usuario
  Future<Either<Failure, List<FuelStation>>> getFavoriteStations();
  
  /// Añade una estación a favoritos
  Future<Either<Failure, bool>> addFavoriteStation(String stationId);
  
  /// Elimina una estación de favoritos
  Future<Either<Failure, bool>> removeFavoriteStation(String stationId);
  
  /// Obtiene información detallada de una estación específica
  Future<Either<Failure, FuelStation>> getStationDetails(String stationId);
  
  /// Busca estaciones por nombre, ciudad o dirección
  Future<Either<Failure, List<FuelStation>>> searchStations(String query);
} 