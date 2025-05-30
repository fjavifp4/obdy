import '../entities/vehicle.dart';
import '../entities/maintenance_record.dart';

abstract class VehicleRepository {
  Future<void> initialize(String token);
  Future<List<Vehicle>> getVehicles();
  Future<Vehicle> addVehicle(Map<String, dynamic> vehicleData);
  Future<void> deleteVehicle(String id);
  Future<Vehicle> updateVehicle(String id, Map<String, dynamic> updates);
  Future<MaintenanceRecord> addMaintenanceRecord(String vehicleId, Map<String, dynamic> recordData);
  Future<MaintenanceRecord> updateMaintenanceRecord(String vehicleId, Map<String, dynamic> recordData);
  Future<MaintenanceRecord> completeMaintenanceRecord(String vehicleId, String maintenanceId);
  Future<void> deleteMaintenanceRecord(String vehicleId, String maintenanceId);
  Future<void> uploadManual(String vehicleId, List<int> fileBytes, String filename);
  Future<List<int>> downloadManual(String vehicleId);
  Future<bool> checkManualExists(String vehicleId);
  Future<List<Map<String, dynamic>>> analyzeMaintenanceManual(String vehicleId);
  Future<void> deleteManual(String vehicleId);
  Future<void> updateManual(String vehicleId, List<int> fileBytes, String filename);
  Future<void> updateItv(String vehicleId, DateTime itvDate);
  Future<void> completeItv(String vehicleId);
} 
