import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/vehicle_repository.dart';
import 'manual_event.dart';
import 'manual_state.dart';

class ManualBloc extends Bloc<ManualEvent, ManualState> {
  final VehicleRepository _vehicleRepository;

  ManualBloc({
    required VehicleRepository vehicleRepository,
  }) : _vehicleRepository = vehicleRepository,
       super(ManualInitial()) {
    on<CheckManualExists>(_handleCheckManualExists);
    on<DownloadManual>(_handleDownloadManual);
    on<UploadManual>(_handleUploadManual);
  }

  Future<void> _handleCheckManualExists(
    CheckManualExists event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      final hasManual = await _vehicleRepository.checkManualExists(event.vehicleId);
      emit(ManualExists(hasManual));
    } catch (e) {
      emit(ManualError('Error al verificar el manual. Por favor, intente de nuevo.'));
    }
  }

  Future<void> _handleDownloadManual(
    DownloadManual event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      final fileBytes = await _vehicleRepository.downloadManual(event.vehicleId);
      emit(ManualDownloaded(fileBytes));
    } catch (e) {
      emit(ManualError('Error al descargar el manual. Por favor, intente de nuevo.'));
    }
  }

  Future<void> _handleUploadManual(
    UploadManual event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      await _vehicleRepository.uploadManual(
        event.vehicleId,
        event.fileBytes,
        event.filename,
      );
      emit(ManualExists(true));
    } catch (e) {
      emit(ManualError('Error al subir el manual. Por favor, intente de nuevo.'));
    }
  }
} 