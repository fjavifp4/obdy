import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

class StartBluetoothScan extends BluetoothEvent {}
class StopBluetoothScan extends BluetoothEvent {}
class ConnectToDevice extends BluetoothEvent {
  final BluetoothDevice device;
  const ConnectToDevice(this.device);

  @override
  List<Object> get props => [device];
}

class BluetoothConnected extends BluetoothEvent {
  final BluetoothDevice device;
  const BluetoothConnected(this.device);

  @override
  List<Object?> get props => [device];
}

class BluetoothDisconnected extends BluetoothEvent {} 