import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/fuel_station.dart';
import 'package:obdy/domain/repositories/fuel_repository.dart';

/// Caso de uso para buscar estaciones por nombre, dirección o ciudad
class SearchStations {
  final FuelRepository _repository;

  SearchStations(this._repository);

  /// Busca estaciones que coincidan con la consulta de búsqueda
  /// 
  /// [query] es el término de búsqueda (nombre, dirección, ciudad, etc.)
  Future<Either<Failure, List<FuelStation>>> call(String query) async {
    return await _repository.searchStations(query);
  }
} 
