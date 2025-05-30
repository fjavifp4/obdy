import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  BluetoothBloc() : super(const BluetoothState()) {
    on<StartBluetoothScan>(_onStartBluetoothScan);
    on<StopBluetoothScan>(_onStopBluetoothScan);
    on<ConnectToDevice>(_onConnectToDevice);
    on<BluetoothConnected>(_onBluetoothConnected);
    on<BluetoothDisconnected>(_onBluetoothDisconnected);
  }

  Future<void> _onStartBluetoothScan(
    StartBluetoothScan event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(isScanning: true));
    try {
      fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      final devices = await fbp.FlutterBluePlus.connectedSystemDevices;
      emit(state.copyWith(devices: devices, isScanning: false));
    } catch (e) {
      emit(state.copyWith(
        error: 'Error al escanear: ${e.toString()}',
        isScanning: false,
      ));
    }
  }

  Future<void> _onStopBluetoothScan(
    StopBluetoothScan event,
    Emitter<BluetoothState> emit,
  ) async {
    await fbp.FlutterBluePlus.stopScan();
    emit(state.copyWith(isScanning: false));
  }

  Future<void> _onConnectToDevice(
    ConnectToDevice event,
    Emitter<BluetoothState> emit,
  ) async {
    try {
      await event.device.connect();
      emit(state.copyWith(status: BluetoothConnectionStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        error: 'Error al conectar: ${e.toString()}',
        status: BluetoothConnectionStatus.disconnected,
      ));
    }
  }

  void _onBluetoothConnected(
    BluetoothConnected event,
    Emitter<BluetoothState> emit,
  ) {
    emit(state.copyWith(status: BluetoothConnectionStatus.connected));
  }

  void _onBluetoothDisconnected(
    BluetoothDisconnected event,
    Emitter<BluetoothState> emit,
  ) {
    emit(state.copyWith(status: BluetoothConnectionStatus.disconnected));
  }
} 
