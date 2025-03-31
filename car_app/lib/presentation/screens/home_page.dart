import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'diagnostic_screen.dart';
import 'profile_screen.dart';
import 'garage_screen.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
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
    final isDarkMode = context.watch<ThemeBloc>().state;
    
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
              backgroundColor: isDarkMode
                  ? Color(0xFF2A2A2D)
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isDarkMode
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onPrimary,
              elevation: isDarkMode ? 0 : 2,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.light,
              ),
              
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
                backgroundColor: isDarkMode
                    ? Color(0xFF2A2A2D)
                    : Theme.of(context).colorScheme.primary,
                selectedItemColor: isDarkMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onPrimary,
                unselectedItemColor: isDarkMode
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                elevation: isDarkMode ? 0 : 8,
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
} 