part of 'obd_bloc.dart';

enum OBDStatus {
  initial,
  initialized,
  connecting,
  connected,
  disconnected,
  error,
}

class OBDState extends Equatable {
  final OBDStatus status;
  final bool isSimulationMode;
  final bool isLoading;
  final String? error;
  final Map<String, Map<String, dynamic>> parametersData;
  final List<String> dtcCodes;
  final List<String>? supportedPids;
  final List<BluetoothDevice> devices;

  const OBDState({
    this.status = OBDStatus.initial,
    this.isSimulationMode = false,
    this.isLoading = false,
    this.error,
    this.parametersData = const {},
    this.dtcCodes = const [],
    this.supportedPids,
    this.devices = const [],
  });

  const OBDState.initial() : 
    status = OBDStatus.initial,
    error = null,
    parametersData = const {},
    dtcCodes = const [],
    supportedPids = null,
    isLoading = false,
    isSimulationMode = false,
    devices = const [];

  OBDState copyWith({
    OBDStatus? status,
    bool? isSimulationMode,
    bool? isLoading,
    String? error,
    Map<String, Map<String, dynamic>>? parametersData,
    List<String>? dtcCodes,
    List<String>? supportedPids,
    List<BluetoothDevice>? devices,
  }) {
    return OBDState(
      status: status ?? this.status,
      isSimulationMode: isSimulationMode ?? this.isSimulationMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      parametersData: parametersData ?? this.parametersData,
      dtcCodes: dtcCodes ?? this.dtcCodes,
      supportedPids: supportedPids ?? this.supportedPids,
      devices: devices ?? this.devices,
    );
  }

  @override
  List<Object?> get props => [
    status, 
    isSimulationMode, 
    isLoading, 
    error, 
    parametersData,
    dtcCodes,
    supportedPids,
    devices,
  ];
}
