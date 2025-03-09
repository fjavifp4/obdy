import 'package:car_app/domain/repositories/fuel_repository.dart';

/// Caso de uso para inicializar el repositorio de combustible
class InitializeFuelRepository {
  final FuelRepository _repository;

  InitializeFuelRepository(this._repository);

  /// Inicializa el repositorio con el token de autenticación
  Future<void> call(String token) async {
    await _repository.initialize(token);
  }
} 