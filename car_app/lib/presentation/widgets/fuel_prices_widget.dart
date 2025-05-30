import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obdy/presentation/blocs/fuel/fuel_bloc.dart';
import 'package:obdy/presentation/blocs/fuel/fuel_event.dart';
import 'package:obdy/presentation/blocs/fuel/fuel_state.dart';
import 'package:obdy/domain/entities/fuel_station.dart';

/// Widget que muestra los precios generales de combustible
class FuelPricesWidget extends StatefulWidget {
  const FuelPricesWidget({super.key});

  @override
  State<FuelPricesWidget> createState() => _FuelPricesWidgetState();
}

class _FuelPricesWidgetState extends State<FuelPricesWidget> {
  bool _initialLoadRequested = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FuelBloc, FuelState>(
      // Reduce rebuilds by only rebuilding when relevant parts of state change
      buildWhen: (previous, current) => 
          previous.generalPrices != current.generalPrices ||
          previous.isLoading != current.isLoading ||
          (previous.error != current.error && current.error != null),
      builder: (context, state) {
        // Solo carga datos si aún no están cargados y no se ha solicitado ya
        if (state.generalPrices == null && !state.isLoading && !_initialLoadRequested) {
          // Marca que ya se ha solicitado la carga para evitar solicitudes repetidas
          _initialLoadRequested = true;
          // Usar Future.microtask para evitar que la llamada ocurra durante el build
          Future.microtask(() {
            if (mounted) {
              context.read<FuelBloc>().add(const LoadGeneralFuelPrices());
            }
          });
        }
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Precios de combustible',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.generalPrices != null) ...[
                  _buildFuelPriceRow('Gasolina 95', state.generalPrices!['gasolina95'] ?? 0.0, Colors.green),
                  const Divider(height: 12),
                  _buildFuelPriceRow('Gasolina 98', state.generalPrices!['gasolina98'] ?? 0.0, Colors.blue),
                  const Divider(height: 12),
                  _buildFuelPriceRow('Diesel', state.generalPrices!['diesel'] ?? 0.0, Colors.amber.shade900),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        context.read<FuelBloc>().add(const LoadGeneralFuelPrices(forceRefresh: true));
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Actualizar precios', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ] else if (!state.isLoading) ...[
                  const Center(
                    child: Text(
                      'No hay datos de precios disponibles',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        context.read<FuelBloc>().add(const LoadGeneralFuelPrices());
                      },
                      child: const Text('Cargar precios'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFuelPriceRow(String name, double price, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.local_gas_station,
              color: color,
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${price.toStringAsFixed(3)} €/L',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 
