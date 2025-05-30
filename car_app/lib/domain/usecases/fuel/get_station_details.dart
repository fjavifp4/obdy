import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/fuel_station.dart';
import 'package:obdy/domain/repositories/fuel_repository.dart';

/// Caso de uso para obtener los detalles de una estación específica
class GetStationDetails {
  final FuelRepository _repository;

  GetStationDetails(this._repository);

  /// Obtiene información detallada de una estación de servicio
  /// 
  /// [stationId] es el identificador único de la estación
  Future<Either<Failure, FuelStation>> call(String stationId) async {
    return await _repository.getStationDetails(stationId);
  }
} 
