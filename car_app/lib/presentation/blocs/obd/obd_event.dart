import 'package:equatable/equatable.dart';
import 'package:car_app/config/core/either.dart';
import 'package:car_app/config/core/failures.dart';
import '../../../domain/entities/obd_data.dart';

abstract class OBDEvent extends Equatable {
  const OBDEvent();

  @override
  List<Object?> get props => [];
}

class InitializeOBDEvent extends OBDEvent {}

class ConnectToOBD extends OBDEvent {}

class DisconnectFromOBD extends OBDEvent {}

class StartParameterMonitoring extends OBDEvent {
  final String pid;
  
  const StartParameterMonitoring(this.pid);
  
  @override
  List<Object> get props => [pid];
}

class StopParameterMonitoring extends OBDEvent {
  final String pid;
  
  const StopParameterMonitoring(this.pid);
  
  @override
  List<Object> get props => [pid];
}

class UpdateParameterData extends OBDEvent {
  final String pid;
  final Either<Failure, OBDData> result;
  
  const UpdateParameterData(this.pid, this.result);
  
  @override
  List<Object> get props => [pid, result];
}

class GetDTCCodes extends OBDEvent {}

class ClearDTCCodes extends OBDEvent {}

class ToggleSimulationMode extends OBDEvent {
  const ToggleSimulationMode();
}