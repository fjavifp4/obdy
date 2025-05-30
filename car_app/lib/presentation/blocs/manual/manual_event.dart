import 'package:equatable/equatable.dart';

abstract class ManualEvent extends Equatable {
  const ManualEvent();

  @override
  List<Object?> get props => [];
}

class InitializeManual extends ManualEvent {
  final String token;
  const InitializeManual(this.token);

  @override
  List<Object> get props => [token];
}

class CheckManualExists extends ManualEvent {
  final String vehicleId;
  const CheckManualExists(this.vehicleId);

  @override
  List<Object> get props => [vehicleId];
}

class DownloadManual extends ManualEvent {
  final String vehicleId;
  const DownloadManual(this.vehicleId);

  @override
  List<Object> get props => [vehicleId];
}

class UploadManual extends ManualEvent {
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

class DeleteManual extends ManualEvent {
  final String vehicleId;
  const DeleteManual(this.vehicleId);

  @override
  List<Object> get props => [vehicleId];
}

class UpdateManual extends ManualEvent {
  final String vehicleId;
  final List<int> fileBytes;
  final String filename;

  const UpdateManual({
    required this.vehicleId,
    required this.fileBytes,
    required this.filename,
  });

  @override
  List<Object> get props => [vehicleId, fileBytes, filename];
} 
