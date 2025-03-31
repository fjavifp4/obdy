import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';

class OBDConnectionDialog extends StatefulWidget {
  const OBDConnectionDialog({super.key});

  @override
  State<OBDConnectionDialog> createState() => _OBDConnectionDialogState();
}

class _OBDConnectionDialogState extends State<OBDConnectionDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // Configurar la animación
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Repetir la animación indefinidamente
    _animationController.repeat();
    
    // Iniciar búsqueda
    // Usar addPostFrameCallback para asegurar que se ejecute después 
    // de que el widget esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OBDBloc>().add(InitializeOBDEvent());
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: BlocBuilder<OBDBloc, OBDState>(
        builder: (context, state) {
          bool isSearching = state.status == OBDStatus.initial || 
                             state.isLoading ||
                             state.status == OBDStatus.connecting;
                         
          return Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  children: [
                    Icon(
                      isSearching ? Icons.bluetooth_searching : Icons.bluetooth,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Buscar dispositivo OBD',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Animación de búsqueda
                if (isSearching)
                  Column(
                    children: [
                      SizedBox(
                        height: 4,
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              widthFactor: 0.3,
                              alignment: Alignment(_animation.value, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                height: 4,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.status == OBDStatus.connecting
                            ? 'Conectando al dispositivo...'
                            : 'Buscando dispositivos OBD...',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                // Mensaje de error si existe
                if (state.error != null && state.error!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, 
                          color: Colors.red, 
                          size: 20
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Lista de dispositivos encontrados
                if (state.devices.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.devices.length,
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        return ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color: colorScheme.primary,
                          ),
                          title: Text(device.platformName),
                          subtitle: Text(device.id.toString()),
                          onTap: () {
                            context.read<OBDBloc>().add(ConnectToOBD());
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  )
                else if (state.status != OBDStatus.initial && state.devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 48,
                            color: isDarkMode 
                                ? Colors.grey[600] 
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron dispositivos OBD',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDarkMode 
                                  ? Colors.grey[400] 
                                  : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botones de acción
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isSearching
                          ? null
                          : () {
                              // Usar addPostFrameCallback para asegurar que no se emita
                              // después de que el widget se haya dibujado
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                context.read<OBDBloc>().add(InitializeOBDEvent());
                              });
                            },
                      icon: Icon(
                        Icons.refresh,
                        color: isSearching 
                            ? Colors.grey 
                            : colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Buscar',
                        style: TextStyle(
                          color: isSearching 
                              ? Colors.grey 
                              : colorScheme.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        backgroundColor: colorScheme.primary,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 