import '../../../domain/entities/vehicle.dart';

abstract class VehicleState {
  const VehicleState();
}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  const VehicleLoaded(this.vehicles);
}

class ManualExists extends VehicleState {
  final bool exists;
  const ManualExists(this.exists);
}

class ManualDownloaded extends VehicleState {
  final List<int> fileBytes;
  const ManualDownloaded(this.fileBytes);
}

class VehicleError extends VehicleState {
  final String message;
  const VehicleError(this.message);
}

class ManualOperationInProgress extends VehicleState {}

class VehicleManualUploading extends VehicleState {}

class VehicleManualUploadSuccess extends VehicleState {}

class VehicleManualUploadError extends VehicleState {
  final String error;

  const VehicleManualUploadError(this.error);

  @override
  List<Object> get props => [error];
}

class MaintenanceAnalysisInProgress extends VehicleState {}

class MaintenanceAnalysisComplete extends VehicleState {
  final List<Map<String, dynamic>> recommendations;
  const MaintenanceAnalysisComplete(this.recommendations);
} 
