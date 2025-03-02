// lib/domain/usecases/obd/check_obd_connection.dart
import '../../repositories/obd_repository.dart';

class CheckOBDConnection {
  final OBDRepository repository;

  CheckOBDConnection(this.repository);

  bool call() {
    return repository.isConnected;
  }
}