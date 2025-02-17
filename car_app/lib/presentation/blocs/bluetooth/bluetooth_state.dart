import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BluetoothConnectionStatus { disconnected, connected }

class BluetoothState extends Equatable {
  final List<BluetoothDevice> devices;
  final bool isScanning;
  final String error;
  final BluetoothConnectionStatus status;

  const BluetoothState({
    this.devices = const [],
    this.isScanning = false,
    this.error = '',
    this.status = BluetoothConnectionStatus.disconnected,
  });

  BluetoothState copyWith({
    List<BluetoothDevice>? devices,
    bool? isScanning,
    String? error,
    BluetoothConnectionStatus? status,
  }) {
    return BluetoothState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      error: error ?? this.error,
      status: status ?? this.status,
    );
  }

  @override
  List<Object> get props => [devices, isScanning, error, status];
} 