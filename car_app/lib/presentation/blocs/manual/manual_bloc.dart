import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/vehicle_repository.dart';
import 'manual_event.dart';
import 'manual_state.dart';

class ManualBloc extends Bloc<ManualEvent, ManualState> {
  final VehicleRepository vehicleRepository;

  ManualBloc({
    required this.vehicleRepository,
  }) : super(ManualInitial()) {
    on<InitializeManual>(_handleInitialize);
    on<CheckManualExists>(_handleCheckManualExists);
    on<DownloadManual>(_handleDownloadManual);
    on<UploadManual>(_handleUploadManual);
    on<DeleteManual>(_handleDeleteManual);
    on<UpdateManual>(_handleUpdateManual);
  }

  Future<void> _handleInitialize(
    InitializeManual event,
    Emitter<ManualState> emit,
  ) async {
    try {
      await vehicleRepository.initialize(event.token);
    } catch (e) {
      emit(ManualError('Error al inicializar el manual: $e'));
    }
  }

  Future<void> _handleCheckManualExists(
    CheckManualExists event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      final hasManual = await vehicleRepository.checkManualExists(event.vehicleId);
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
      final fileBytes = await vehicleRepository.downloadManual(event.vehicleId);
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
      await vehicleRepository.uploadManual(
        event.vehicleId,
        event.fileBytes,
        event.filename,
      );
      emit(ManualExists(true));
    } catch (e) {
      emit(ManualError('Error al subir el manual. Por favor, intente de nuevo.'));
    }
  }

  Future<void> _handleDeleteManual(
    DeleteManual event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      await vehicleRepository.deleteManual(event.vehicleId);
      emit(ManualDeleted());
    } catch (e) {
      emit(ManualError('Error al eliminar el manual. Por favor, intente de nuevo.'));
    }
  }

  Future<void> _handleUpdateManual(
    UpdateManual event,
    Emitter<ManualState> emit,
  ) async {
    try {
      emit(ManualLoading());
      await vehicleRepository.updateManual(
        event.vehicleId,
        event.fileBytes,
        event.filename,
      );
      emit(ManualUpdated());
    } catch (e) {
      emit(ManualError('Error al actualizar el manual. Por favor, intente de nuevo.'));
    }
  }
} 
