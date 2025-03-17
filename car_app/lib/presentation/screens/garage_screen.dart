import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:car_app/presentation/blocs/blocs.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/add_vehicle_dialog.dart';
import '../widgets/background_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  bool _isSingleColumn = true;
  static const String _prefKey = 'garage_view_single_column';
  
  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }
  
  // Carga la preferencia guardada
  Future<void> _loadViewPreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? isSingleColumn = prefs.getBool(_prefKey);
      if (isSingleColumn != null) {
        setState(() {
          _isSingleColumn = isSingleColumn;
        });
      }
      // Si es null, mantiene el valor predeterminado (true)
    } catch (e) {
      // Si hay algún error, se mantiene el valor predeterminado
      debugPrint('Error al cargar preferencia de vista: $e');
    }
  }
  
  // Guarda la preferencia cuando cambia
  Future<void> _saveViewPreference(bool isSingleColumn) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, isSingleColumn);
    } catch (e) {
      debugPrint('Error al guardar preferencia de vista: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: BlocBuilder<VehicleBloc, VehicleState>(
        builder: (context, state) {
          if (state is VehicleInitial) {
            context.read<VehicleBloc>().add(LoadVehicles());
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VehicleLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VehicleError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is VehicleLoaded) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(_isSingleColumn ? Icons.grid_view : Icons.view_agenda),
                          onPressed: () {
                            setState(() {
                              _isSingleColumn = !_isSingleColumn;
                              _saveViewPreference(_isSingleColumn);
                            });
                          },
                          tooltip: _isSingleColumn ? 'Ver en cuadrícula' : 'Ver en lista',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.vehicles.isEmpty
                        ? const Center(child: Text('No hay vehículos registrados'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _isSingleColumn ? 1 : 2,
                              childAspectRatio: _isSingleColumn ? 2.0 : 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: state.vehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = state.vehicles[index];
                              return VehicleCard(
                                vehicleId: vehicle.id,
                                onDelete: () {
                                  context.read<VehicleBloc>().add(DeleteVehicle(vehicle.id));
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddVehicleDialog(),
                  );
                },
                child: const Icon(Icons.add),
              ),
            );
          }

          return const Center(child: Text('Estado no manejado'));
        },
      ),
    );
  }
} 