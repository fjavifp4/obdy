import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/vehicle_manual_section.dart';
import '../widgets/vehicle_info_tab.dart';
import '../widgets/maintenance_tab.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'package:get_it/get_it.dart';
import '../widgets/background_container.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String vehicleId;
  static final GlobalKey<_VehicleDetailsScreenState> globalKey = GlobalKey<_VehicleDetailsScreenState>();

  const VehicleDetailsScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  _VehicleDetailsScreenState createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  String? _currentVehicleBrand;
  String? _currentVehicleModel;
  int _selectedIndex = 0;
  late final List<Widget> _tabs;

  void setSelectedIndex(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
      
      if (index == 0) {
        context.read<VehicleBloc>().add(LoadVehicles());
      } else if (index == 1) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          context.read<VehicleBloc>().add(AnalyzeMaintenanceManual(widget.vehicleId));
        });
      } else if (index == 2) {
        context.read<ManualBloc>().add(CheckManualExists(widget.vehicleId));
      }
    }
  }

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
    return BlocProvider<VehicleBloc>.value(
      value: context.read<VehicleBloc>(),
      child: Builder(
        builder: (context) => PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            if (didPop) {
              context.read<VehicleBloc>().add(LoadVehicles());
            }
          },
          child: BackgroundContainer(
            child: BlocConsumer<VehicleBloc, VehicleState>(
              listener: (context, state) {
                if (state is VehicleLoaded) {
                  _updateCurrentVehicleInfo(state);
                }
              },
              builder: (context, state) {
                Widget buildScaffold({Widget? customBody}) {
                  return Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      backgroundColor: Theme.of(context).colorScheme.brightness == Brightness.dark
                          ? Color(0xFF2A2A2D)
                          : Theme.of(context).colorScheme.primary,
                      elevation: Theme.of(context).colorScheme.brightness == Brightness.dark ? 0 : 2,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: Theme.of(context).colorScheme.brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onPrimary,
                        onPressed: () {
                          context.read<VehicleBloc>().add(LoadVehicles());
                          Navigator.of(context).pop();
                        },
                      ),
                      title: Text(
                        _currentVehicleBrand != null && _currentVehicleModel != null
                            ? '$_currentVehicleBrand $_currentVehicleModel'
                            : 'Vehículo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    body: customBody ?? _tabs[_selectedIndex],
                    bottomNavigationBar: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Theme.of(context).colorScheme.brightness == Brightness.dark 
                            ? Color(0xFF2A2A2D)
                            : Theme.of(context).colorScheme.primary,
                      ),
                      child: BottomNavigationBar(
                        currentIndex: _selectedIndex,
                        onTap: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                          if (index == 0) {
                            context.read<VehicleBloc>().add(LoadVehicles());
                          } else if (index == 2) {
                            context.read<ManualBloc>().add(CheckManualExists(widget.vehicleId));
                          }
                        },
                        selectedItemColor: Theme.of(context).colorScheme.brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onPrimary,
                        unselectedItemColor: Theme.of(context).colorScheme.brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                            : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.info_outline),
                            activeIcon: Icon(Icons.info),
                            label: 'Información',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.build_outlined),
                            activeIcon: Icon(Icons.build),
                            label: 'Mantenimiento',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.book_outlined),
                            activeIcon: Icon(Icons.book),
                            label: 'Manual',
                          ),
                        ],
                      ),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
} 