import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'package:car_app/domain/repositories/fuel_repository.dart';

/// Caso de uso para obtener estaciones de servicio cercanas
class GetNearbyStations {
  final FuelRepository _repository;

  GetNearbyStations(this._repository);

  /// Obtiene una lista de estaciones de servicio cercanas a la ubicación dada
  /// 
  /// [latitude] y [longitude] definen la ubicación central
  /// [radius] es el radio de búsqueda en kilómetros (por defecto 5km)
  /// [fuelType] filtra por un tipo específico de combustible (opcional)
  Future<Either<Failure, List<FuelStation>>> call({
    required double latitude,
    required double longitude,
    double radius = 5.0,
    String? fuelType,
  }) async {
    return await _repository.getNearbyStations(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      fuelType: fuelType,
    );
  }
} 