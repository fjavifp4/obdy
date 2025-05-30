part of 'obd_bloc.dart';

abstract class OBDEvent extends Equatable {
  const OBDEvent();

  @override
  List<Object?> get props => [];
}

class InitializeOBDEvent extends OBDEvent {}

class ConnectToOBD extends OBDEvent {}

class DisconnectFromOBD extends OBDEvent {
  const DisconnectFromOBD();
}

class DisconnectFromOBDPreserveSimulation extends DisconnectFromOBD {
  const DisconnectFromOBDPreserveSimulation();
}

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

class FetchSupportedPids extends OBDEvent {}
