import 'package:equatable/equatable.dart';

abstract class VehicleEvent extends Equatable {
  const VehicleEvent();

  @override
  List<Object?> get props => [];
}

class InitializeVehicleRepository extends VehicleEvent {
  final String token;

  const InitializeVehicleRepository(this.token);

  @override
  List<Object> get props => [token];
}

class LoadVehicles extends VehicleEvent {}

class AddVehicle extends VehicleEvent {
  final Map<String, dynamic> vehicle;

  const AddVehicle(this.vehicle);

  @override
  List<Object> get props => [vehicle];
}

class UpdateVehicle extends VehicleEvent {
  final String id;
  final Map<String, dynamic> updates;

  const UpdateVehicle({
    required this.id,
    required this.updates,
  });

  @override
  List<Object> get props => [id, updates];
}

class DeleteVehicle extends VehicleEvent {
  final String id;

  const DeleteVehicle(this.id);

  @override
  List<Object> get props => [id];
}

class AddMaintenanceRecord extends VehicleEvent {
  final String vehicleId;
  final Map<String, dynamic> record;

  const AddMaintenanceRecord({
    required this.vehicleId,
    required this.record,
  });

  @override
  List<Object> get props => [vehicleId, record];
}

class UpdateMaintenanceRecord extends VehicleEvent {
  final String vehicleId;
  final Map<String, dynamic> record;

  const UpdateMaintenanceRecord({
    required this.vehicleId,
    required this.record,
  });

  @override
  List<Object> get props => [vehicleId, record];
}

class DeleteMaintenanceRecord extends VehicleEvent {
  final String vehicleId;
  final String maintenanceId;

  const DeleteMaintenanceRecord({
    required this.vehicleId,
    required this.maintenanceId,
  });

  @override
  List<Object> get props => [vehicleId, maintenanceId];
}

class UploadManual extends VehicleEvent {
  final String vehicleId;
  final List<int> fileBytes;
  final String filename;

  const UploadManual({
    required this.vehicleId,
    required this.fileBytes,
    required this.filename,
  });

  @override
  List<Object> get props => [vehicleId, fileBytes, filename];
}

class DownloadManual extends VehicleEvent {
  final String vehicleId;

  const DownloadManual(this.vehicleId);

  @override
  List<Object> get props => [vehicleId];
}

class CheckManualExists extends VehicleEvent {
  final String vehicleId;

  const CheckManualExists(this.vehicleId);

  @override
  List<Object> get props => [vehicleId];
} 