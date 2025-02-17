import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/vehicle_manual_section.dart';
import '../widgets/vehicle_info_tab.dart';
import '../widgets/maintenance_tab.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'package:get_it/get_it.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String vehicleId;

  const VehicleDetailsScreen({
    Key? key,
    required this.vehicleId,
  }) : super(key: key);

  @override
  _VehicleDetailsScreenState createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  String? _currentVehicleBrand;
  String? _currentVehicleModel;
  int _selectedIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    final vehicleBloc = context.read<VehicleBloc>();
    final currentState = vehicleBloc.state;
    
    if (currentState is! VehicleLoaded) {
      vehicleBloc.add(LoadVehicles());
    } else {
      _updateCurrentVehicleInfo(currentState);
    }

    _tabs = [
      VehicleInfoTab(vehicleId: widget.vehicleId),
      MaintenanceTab(vehicleId: widget.vehicleId),
      VehicleManualSection(vehicleId: widget.vehicleId),
    ];
  }

  Future<bool> _onWillPop() async {
    context.read<VehicleBloc>().add(LoadVehicles());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.instance<ManualBloc>(),
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          if (didPop) {
            context.read<VehicleBloc>().add(LoadVehicles());
          }
        },
        child: BlocConsumer<VehicleBloc, VehicleState>(
          listener: (context, state) {
            if (state is VehicleLoaded) {
              _updateCurrentVehicleInfo(state);
            }
          },
          builder: (context, state) {
            Widget buildScaffold({Widget? customBody}) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      context.read<VehicleBloc>().add(LoadVehicles());
                      Navigator.of(context).pop();
                    },
                  ),
                  title: Text(_currentVehicleBrand != null && _currentVehicleModel != null
                      ? '$_currentVehicleBrand $_currentVehicleModel'
                      : 'Vehículo'),
                ),
                body: customBody ?? _tabs[_selectedIndex],
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (_selectedIndex != index) {
                      setState(() => _selectedIndex = index);
                      if (index == 2) { // Tab del manual
                        context.read<ManualBloc>().add(
                          CheckManualExists(widget.vehicleId)
                        );
                      } else {
                        context.read<VehicleBloc>().add(LoadVehicles());
                      }
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.directions_car),
                      label: 'Información',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.build),
                      label: 'Mantenimiento',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.book),
                      label: 'Manual',
                    ),
                  ],
                ),
              );
            }

            if (state is VehicleLoading) {
              return buildScaffold(
                customBody: const Center(child: CircularProgressIndicator()),
              );
            }

            if (state is VehicleError) {
              return buildScaffold(
                customBody: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.message),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_selectedIndex == 2) {
                            context.read<ManualBloc>().add(
                              CheckManualExists(widget.vehicleId)
                            );
                          } else {
                            context.read<VehicleBloc>().add(LoadVehicles());
                          }
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return buildScaffold();
          },
        ),
      ),
    );
  }

  void _updateCurrentVehicleInfo(VehicleLoaded state) {
    try {
      final vehicle = state.vehicles.firstWhere(
        (v) => v.id == widget.vehicleId,
      );
      setState(() {
        _currentVehicleBrand = vehicle.brand;
        _currentVehicleModel = vehicle.model;
      });
    } catch (e) {
      print('Error al encontrar el vehículo: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
} 