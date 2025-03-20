import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'config/theme/theme_config.dart';
import 'presentation/screens/home_page.dart';
import 'presentation/screens/login_page.dart';
import 'presentation/screens/register_page.dart';
import 'presentation/blocs/service_locator.dart';
import 'presentation/blocs/blocs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/usecases/usecases.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar datos de localización para fechas en español
  await initializeDateFormatting('es_ES', null);
  
  final prefs = await SharedPreferences.getInstance();
  await setupServiceLocator();
  runApp(BlocsProviders(prefs: prefs));
}

class BlocsProviders extends StatelessWidget {
  final SharedPreferences prefs;
  
  const BlocsProviders({
    super.key,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(
            loginUser: GetIt.I.get<LoginUser>(),
            registerUser: GetIt.I.get<RegisterUser>(),
            getUserData: GetIt.I.get<GetUserData>(),
            changePassword: GetIt.I.get<ChangePassword>(),
            logoutUser: GetIt.I.get<LogoutUser>(),
            initializeRepositories: GetIt.I.get<InitializeRepositories>(),
          ),
        ),
        BlocProvider(
          create: (_) => VehicleBloc(
            initializeVehicle: GetIt.I.get(),
            getVehicles: GetIt.I.get(),
            addVehicle: GetIt.I.get(),
            updateVehicle: GetIt.I.get(),
            deleteVehicle: GetIt.I.get(),
            addMaintenanceRecord: GetIt.I.get(),
            updateMaintenanceRecord: GetIt.I.get(),
            completeMaintenanceRecord: GetIt.I.get(),
            uploadManual: GetIt.I.get(),
            downloadManual: GetIt.I.get(),
            deleteMaintenanceRecord: GetIt.I.get(),
            analyzeMaintenanceManual: GetIt.I.get(),
            deleteManual: GetIt.I.get(),
            updateManual: GetIt.I.get(),
            updateItv: GetIt.I.get(),
            completeItv: GetIt.I.get(),
          ),
        ),
        BlocProvider(
          create: (_) => BluetoothBloc(),
        ),
        BlocProvider(
          create: (_) => ChatBloc(
            getOrCreateChat: GetIt.I.get(),
            createChat: GetIt.I.get(),
            addMessage: GetIt.I.get(),
            clearChat: GetIt.I.get(),
            initializeRepositories: GetIt.I.get(),
          ),
        ),
        BlocProvider(
          create: (_) => ThemeBloc(prefs),
        ),
        BlocProvider(
          create: (_) => GetIt.I.get<OBDBloc>(),
        ),
        BlocProvider(
          create: (_) => GetIt.I.get<TripBloc>(),
        ),
        BlocProvider(
          create: (_) => GetIt.I.get<HomeBloc>(),
        ),
        BlocProvider(
          create: (_) => GetIt.I.get<FuelBloc>(),
        ),
      ],
      child: MyApp(prefs: prefs),
    );
  }
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const MyApp({
    super.key,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car App',
      theme: AppTheme.getTheme(false).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontWeight: FontWeight.normal, // Evitar mayúsculas
            ),
          ),
        ),
      ),
      darkTheme: AppTheme.getTheme(true).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontWeight: FontWeight.normal, // Evitar mayúsculas
            ),
          ),
        ),
      ),
      themeMode: context.watch<ThemeBloc>().state ? ThemeMode.dark : ThemeMode.light,
      
      // Configuración de localización
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (fallback)
      ],
      
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const HomePage(),
        );
      },
    );
  }
}
