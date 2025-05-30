// lib/domain/repositories/obd_repository.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../entities/obd_data.dart';

abstract class OBDRepository {
  Future<void> initialize();
  Future<bool> connect();
  Future<void> disconnect();
  Stream<OBDData> getParameterData(String pid);
  Future<List<String>> getDiagnosticTroubleCodes();  
  Future<List<String>> getSupportedPids();
  bool get isConnected;
  Future<List<BluetoothDevice>> getAvailableDevices();
}
