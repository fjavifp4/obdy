import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  Map<String, String> _diagnosticData = {
    'speed': '0',
    'rpm': '0',
    'voltage': '0',
  };

  @override
  void initState() {
    super.initState();
    _startOBDDataCollection();
  }

  Future<void> _startOBDDataCollection() async {
    final bluetoothState = context.read<BluetoothBloc>().state;
    if (bluetoothState.status != BluetoothConnectionStatus.connected) {
      return;
    }

    // Aquí implementaremos la lógica para obtener datos del OBD
    // Por ahora, simularemos datos
    setState(() {
      _diagnosticData = {
        'speed': '60 km/h',
        'rpm': '2500',
        'voltage': '12.6 V',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        if (state.status != BluetoothConnectionStatus.connected) {
          return const Center(
            child: Text(
              'Conecta un dispositivo OBD para ver diagnósticos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDiagnosticCard(
                'Velocidad',
                _diagnosticData['speed']!,
                Icons.speed,
              ),
              const SizedBox(height: 16),
              _buildDiagnosticCard(
                'RPM',
                _diagnosticData['rpm']!,
                Icons.rotate_right,
              ),
              const SizedBox(height: 16),
              _buildDiagnosticCard(
                'Voltaje Batería',
                _diagnosticData['voltage']!,
                Icons.battery_charging_full,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 