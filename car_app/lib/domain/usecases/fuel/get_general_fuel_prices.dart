import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/repositories/fuel_repository.dart';

/// Caso de uso para obtener los precios generales de combustible
class GetGeneralFuelPrices {
  final FuelRepository _repository;

  GetGeneralFuelPrices(this._repository);

  /// Obtiene un mapa con los precios promedio de combustible a nivel nacional
  Future<Either<Failure, Map<String, double>>> call() async {
    return await _repository.getGeneralFuelPrices();
  }
} 