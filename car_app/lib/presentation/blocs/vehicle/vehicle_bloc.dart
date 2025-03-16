import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/usecases.dart' as usecases;
import 'vehicle_event.dart';
import 'vehicle_state.dart';

class ResetVehicle extends VehicleEvent {}

class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  final usecases.InitializeVehicle _initializeVehicle;
  final usecases.GetVehicles _getVehicles;
  final usecases.AddVehicle _addVehicle;
  final usecases.UpdateVehicle _updateVehicle;
  final usecases.DeleteVehicle _deleteVehicle;
  final usecases.AddMaintenanceRecord _addMaintenanceRecord;
  final usecases.UpdateMaintenanceRecord _updateMaintenanceRecord;
  final usecases.CompleteMaintenanceRecord _completeMaintenanceRecord;
  final usecases.UploadManual _uploadManual;
  final usecases.DownloadManual _downloadManual;
  final usecases.DeleteMaintenanceRecord _deleteMaintenanceRecord;
  final usecases.AnalyzeMaintenanceManual _analyzeMaintenanceManual;
  final usecases.DeleteManual _deleteManual;
  final usecases.UpdateManual _updateManual;
  final usecases.UpdateItv _updateItv;
  final usecases.CompleteItv _completeItv;

  VehicleBloc({
    required usecases.InitializeVehicle initializeVehicle,
    required usecases.GetVehicles getVehicles,
    required usecases.AddVehicle addVehicle,
    required usecases.UpdateVehicle updateVehicle,
    required usecases.DeleteVehicle deleteVehicle,
    required usecases.AddMaintenanceRecord addMaintenanceRecord,
    required usecases.UpdateMaintenanceRecord updateMaintenanceRecord,
    required usecases.CompleteMaintenanceRecord completeMaintenanceRecord,
    required usecases.UploadManual uploadManual,
    required usecases.DownloadManual downloadManual,
    required usecases.DeleteMaintenanceRecord deleteMaintenanceRecord,
    required usecases.AnalyzeMaintenanceManual analyzeMaintenanceManual,
    required usecases.DeleteManual deleteManual,
    required usecases.UpdateManual updateManual,
    required usecases.UpdateItv updateItv,
    required usecases.CompleteItv completeItv,
  }) : _initializeVehicle = initializeVehicle,
       _getVehicles = getVehicles,
       _addVehicle = addVehicle,
       _updateVehicle = updateVehicle,
       _deleteVehicle = deleteVehicle,
       _addMaintenanceRecord = addMaintenanceRecord,
       _updateMaintenanceRecord = updateMaintenanceRecord,
       _completeMaintenanceRecord = completeMaintenanceRecord,
       _uploadManual = uploadManual,
       _downloadManual = downloadManual,
       _deleteMaintenanceRecord = deleteMaintenanceRecord,
       _analyzeMaintenanceManual = analyzeMaintenanceManual,
       _deleteManual = deleteManual,
       _updateManual = updateManual,
       _updateItv = updateItv,
       _completeItv = completeItv,
       super(VehicleInitial()) {
    on<InitializeVehicleRepository>(_handleInitialize);
    on<LoadVehicles>(_onLoadVehicles);
    on<AddVehicle>(_onAddVehicle);
    on<UpdateVehicle>(_onUpdateVehicle);
    on<DeleteVehicle>(_onDeleteVehicle);
    on<AddMaintenanceRecord>(_handleAddMaintenanceRecord);
    on<UpdateMaintenanceRecord>(_handleUpdateMaintenanceRecord);
    on<CompleteMaintenanceRecord>(_handleCompleteMaintenanceRecord);
    on<UploadManual>(_handleUploadManual);
    on<DownloadManual>(_handleDownloadManual);
    on<DeleteMaintenanceRecord>(_onDeleteMaintenanceRecord);
    on<ResetVehicle>((event, emit) => emit(VehicleInitial()));
    on<AnalyzeMaintenanceManual>(_handleAnalyzeMaintenanceManual);
    on<DeleteManualEvent>(_handleDeleteManual);
    on<UpdateManualEvent>(_handleUpdateManual);
    on<UpdateItv>(_onUpdateItv);
    on<CompleteItv>(_onCompleteItv);
  }

  Future<void> _handleInitialize(
    InitializeVehicleRepository event,
    Emitter<VehicleState> emit,
  ) async {
    final result = await _initializeVehicle(event.token);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _onLoadVehicles(
    LoadVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _getVehicles();
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (vehicles) async => emit(VehicleLoaded(vehicles)),
    );
  }

  Future<void> _onAddVehicle(
    AddVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _addVehicle(event.vehicle);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _onUpdateVehicle(
    UpdateVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _updateVehicle(event.id, event.updates);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _onDeleteVehicle(
    DeleteVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _deleteVehicle(event.id);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleAddMaintenanceRecord(
    AddMaintenanceRecord event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _addMaintenanceRecord(
      event.vehicleId,
      event.record,
    );
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleUpdateMaintenanceRecord(
    UpdateMaintenanceRecord event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _updateMaintenanceRecord(
      event.vehicleId,
      event.record,
    );
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleCompleteMaintenanceRecord(
    CompleteMaintenanceRecord event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _completeMaintenanceRecord(
      event.vehicleId,
      event.maintenanceId,
    );
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleUploadManual(
    UploadManual event,
    Emitter<VehicleState> emit,
  ) async {
    emit(ManualOperationInProgress());
    final result = await _uploadManual(
      event.vehicleId,
      event.fileBytes,
      event.filename,
    );
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleDownloadManual(
    DownloadManual event,
    Emitter<VehicleState> emit,
  ) async {
    emit(ManualOperationInProgress());
    final result = await _downloadManual(event.vehicleId);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (fileBytes) async => emit(ManualDownloaded(fileBytes)),
    );
  }

  Future<void> _onDeleteMaintenanceRecord(
    DeleteMaintenanceRecord event,
    Emitter<VehicleState> emit,
  ) async {
    if (state is VehicleLoaded) {
      try {
        final result = await _deleteMaintenanceRecord(
          event.vehicleId,
          event.maintenanceId,
        );
        
        await result.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (_) async {
            final vehicles = await _getVehicles();
            vehicles.fold(
              (failure) async => emit(VehicleError(failure.message)),
              (vehicles) async => emit(VehicleLoaded(vehicles)),
            );
          },
        );
      } catch (e) {
        emit(VehicleError(e.toString()));
      }
    }
  }

  Future<void> _handleAnalyzeMaintenanceManual(
    AnalyzeMaintenanceManual event,
    Emitter<VehicleState> emit,
  ) async {
    emit(MaintenanceAnalysisInProgress());
    final result = await _analyzeMaintenanceManual(event.vehicleId);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (recommendations) async => emit(MaintenanceAnalysisComplete(recommendations)),
    );
  }

  Future<void> _handleDeleteManual(
    DeleteManualEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _deleteManual(event.vehicleId);
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  Future<void> _handleUpdateManual(
    UpdateManualEvent event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    final result = await _updateManual(
      event.vehicleId,
      event.fileBytes,
      event.filename,
    );
    await result.fold(
      (failure) async => emit(VehicleError(failure.message)),
      (_) async {
        final vehiclesResult = await _getVehicles();
        await vehiclesResult.fold(
          (failure) async => emit(VehicleError(failure.message)),
          (vehicles) async => emit(VehicleLoaded(vehicles)),
        );
      },
    );
  }

  void _onUpdateItv(UpdateItv event, Emitter<VehicleState> emit) async {
    emit(VehicleLoading());
    final result = await _updateItv(event.vehicleId, event.itvDate);
    result.fold(
      (failure) => emit(VehicleError(failure.message)),
      (_) => add(LoadVehicles()),
    );
  }

  void _onCompleteItv(CompleteItv event, Emitter<VehicleState> emit) async {
    emit(VehicleLoading());
    final result = await _completeItv(event.vehicleId);
    result.fold(
      (failure) => emit(VehicleError(failure.message)),
      (_) => add(LoadVehicles()),
    );
  }

  void reset() {
    add(ResetVehicle());
  }
} 