import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../blocs/blocs.dart';
import 'diagnostic_screen.dart';
import 'profile_screen.dart';
import 'garage_screen.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import '../widgets/bluetooth_connection_dialog.dart';
import '../../config/theme/background_pattern.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GarageScreen(),
    const DiagnosticScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Inicio',
    'Garaje',
    'Diagnóstico',
    'Chat',
    'Perfil',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthError || state is AuthInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const SizedBox.shrink();
        }

        if (state is! AuthSuccess) {
          return const Center(child: CircularProgressIndicator());
        }

        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_titles[_currentIndex]),
              centerTitle: true,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              ),
              actions: [
                if (_currentIndex == 2)
                  BlocBuilder<BluetoothBloc, BluetoothState>(
                    builder: (context, state) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state.status == BluetoothConnectionStatus.connected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.bluetooth),
                            onPressed: () => _handleBluetoothPressed(context),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            body: Stack(
              children: [
                // Patrón de fondo
                Positioned.fill(
                  child: CustomPaint(
                    painter: BackgroundPattern(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                // Contenido
                _screens[_currentIndex],
              ],
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Theme.of(context).colorScheme.primary,
                selectedItemColor: Theme.of(context).colorScheme.onPrimary,
                unselectedItemColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Inicio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.garage),
                    label: 'Garaje',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.speed),
                    label: 'OBD',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat),
                    label: 'Chat',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBluetoothPressed(BuildContext context) async {
    try {
      final isAvailable = await fbp.FlutterBluePlus.isSupported;
      if (!isAvailable && context.mounted) {
        _showBluetoothError(
          context,
          'Bluetooth Desactivado',
          'Por favor, activa el Bluetooth para continuar.',
        );
        return;
      }
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => const BluetoothConnectionDialog(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showBluetoothError(
          context,
          'Error',
          'No se pudo acceder al Bluetooth. Por favor, verifica que esté activado.',
        );
      }
    }
  }

  void _showBluetoothError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
} 