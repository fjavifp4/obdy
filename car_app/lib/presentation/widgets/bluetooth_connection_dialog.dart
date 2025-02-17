import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';

class BluetoothConnectionDialog extends StatefulWidget {
  const BluetoothConnectionDialog({super.key});

  @override
  State<BluetoothConnectionDialog> createState() => _BluetoothConnectionDialogState();
}

class _BluetoothConnectionDialogState extends State<BluetoothConnectionDialog> {
  late final BluetoothBloc _bluetoothBloc;

  @override
  void initState() {
    super.initState();
    _bluetoothBloc = context.read<BluetoothBloc>();
    _bluetoothBloc.add(StartBluetoothScan());
  }

  @override
  void dispose() {
    _bluetoothBloc.add(StopBluetoothScan());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<BluetoothBloc, BluetoothState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dispositivos OBD disponibles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (state.isScanning)
                  const LinearProgressIndicator(),
                if (state.error.isNotEmpty)
                  Text(
                    state.error,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (state.devices.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.devices.length,
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        return ListTile(
                          title: Text(device.platformName),
                          subtitle: Text(device.remoteId.str),
                          onTap: () {
                            _bluetoothBloc.add(ConnectToDevice(device));
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: state.isScanning
                          ? null
                          : () => _bluetoothBloc.add(StartBluetoothScan()),
                      child: const Text('Buscar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 