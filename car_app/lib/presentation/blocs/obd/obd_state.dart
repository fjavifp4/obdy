// lib/presentation/blocs/obd/obd_state.dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/obd_data.dart';

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
  final String? error;
  final Map<String, Map<String, dynamic>> parametersData;
  final List<String> dtcCodes;
  final bool isLoading;

  const OBDState({
    required this.status,
    this.error,
    required this.parametersData,
    required this.dtcCodes,
    this.isLoading = false,
  });

  const OBDState.initial() : 
    status = OBDStatus.initial,
    error = null,
    parametersData = const {},
    dtcCodes = const [],
    isLoading = false;

  OBDState copyWith({
    OBDStatus? status,
    String? error,
    Map<String, Map<String, dynamic>>? parametersData,
    List<String>? dtcCodes,
    bool? isLoading,
  }) {
    return OBDState(
      status: status ?? this.status,
      error: error,
      parametersData: parametersData ?? this.parametersData,
      dtcCodes: dtcCodes ?? this.dtcCodes,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [status, error, parametersData, dtcCodes, isLoading];
}