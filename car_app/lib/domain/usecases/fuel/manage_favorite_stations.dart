import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/fuel_station.dart';
import 'package:obdy/domain/repositories/fuel_repository.dart';

/// Caso de uso para obtener las estaciones favoritas del usuario
class GetFavoriteStations {
  final FuelRepository _repository;

  GetFavoriteStations(this._repository);

  /// Obtiene la lista de estaciones marcadas como favoritas por el usuario
  Future<Either<Failure, List<FuelStation>>> call() async {
    return await _repository.getFavoriteStations();
  }
}

/// Caso de uso para añadir una estación a favoritos
class AddFavoriteStation {
  final FuelRepository _repository;

  AddFavoriteStation(this._repository);

  /// Añade una estación a la lista de favoritos del usuario
  /// 
  /// [stationId] es el identificador único de la estación
  Future<Either<Failure, bool>> call(String stationId) async {
    return await _repository.addFavoriteStation(stationId);
  }
}

/// Caso de uso para eliminar una estación de favoritos
class RemoveFavoriteStation {
  final FuelRepository _repository;

  RemoveFavoriteStation(this._repository);

  /// Elimina una estación de la lista de favoritos del usuario
  /// 
  /// [stationId] es el identificador único de la estación
  Future<Either<Failure, bool>> call(String stationId) async {
    return await _repository.removeFavoriteStation(stationId);
  }
} 
