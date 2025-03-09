import 'package:equatable/equatable.dart';

/// Clase base para todos los tipos de fallos
abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);
  
  @override
  List<Object> get props => [message];
}

/// Error en el servidor de API
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message);
}

/// Error de conexión a internet
class ConnectionFailure extends Failure {
  const ConnectionFailure(String message) : super(message);
}

/// Error de autenticación
class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message);
}

/// Error de permisos o autorización
class PermissionFailure extends Failure {
  const PermissionFailure(String message) : super(message);
}

/// Error de datos o formato
class DataFailure extends Failure {
  const DataFailure(String message) : super(message);
}

class OBDFailure extends Failure {
  const OBDFailure(String message) : super(message);
}

class TripFailure extends Failure {
  TripFailure(String message) : super(message);
} 