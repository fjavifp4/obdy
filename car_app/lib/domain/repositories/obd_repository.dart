// lib/domain/repositories/obd_repository.dart
import '../entities/obd_data.dart';

abstract class OBDRepository {
  Future<void> initialize();
  Future<bool> connect();
  Future<void> disconnect();
  Stream<OBDData> getParameterData(String pid);
  Future<List<String>> getDiagnosticTroubleCodes();
  bool get isConnected;
}