import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Implementaciones
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/vehicle_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
//import '../../data/repositories/obd_repository_mock.dart';
import '../../data/repositories/obd_repository_provider.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../../data/repositories/fuel_repository_impl.dart';

// Interfaces
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/obd_repository.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/repositories/fuel_repository.dart';

// Casos de uso y blocs
import '../../domain/usecases/usecases.dart' as usecases;
import '../blocs/blocs.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ───────────────────────────────────────────
  // Servicios externos
  // ───────────────────────────────────────────
  getIt.registerSingletonAsync<SharedPreferences>(() async {
    return await SharedPreferences.getInstance();
  });

  await getIt.allReady();

  // ───────────────────────────────────────────
  // Repositorios (Interfaces → Implementaciones)
  // ───────────────────────────────────────────
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
  getIt.registerLazySingleton<VehicleRepository>(() => VehicleRepositoryImpl());
  getIt.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl());
  
  // Registramos OBDRepositoryProvider como singleton para poder cambiar el modo
  getIt.registerLazySingleton<OBDRepositoryProvider>(() => OBDRepositoryProvider());
  // Y lo usamos como implementación del OBDRepository
  getIt.registerLazySingleton<OBDRepository>(() => getIt<OBDRepositoryProvider>());
  
  getIt.registerLazySingleton<TripRepository>(() => TripRepositoryImpl(vehicleRepository: getIt<VehicleRepository>()));
  
  // Repositorio de precios de combustible
  getIt.registerLazySingleton<FuelRepository>(() => FuelRepositoryImpl());

  // ───────────────────────────────────────────
  // Casos de Uso
  // ───────────────────────────────────────────
  // 🔹 Autenticación
  getIt.registerLazySingleton(() => usecases.LoginUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => usecases.RegisterUser(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => usecases.GetUserData(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => usecases.ChangePassword(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => usecases.LogoutUser(getIt<AuthRepository>()));

  getIt.registerLazySingleton(() => usecases.InitializeRepositories(
    vehicleRepository: getIt<VehicleRepository>(),
    chatRepository: getIt<ChatRepository>(),
    obdRepository: getIt<OBDRepository>(),
    tripRepository: getIt<TripRepository>(),
    fuelRepository: getIt<FuelRepository>(),
  ));

  // 🔹 Chat
  getIt.registerLazySingleton(() => usecases.GetOrCreateChat(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => usecases.CreateChat(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => usecases.AddMessage(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => usecases.ClearChat(getIt<ChatRepository>()));

  // 🔹 Vehículos
  getIt.registerLazySingleton(() => usecases.InitializeVehicle(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.GetVehicles(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.AddVehicle(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateVehicle(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DeleteVehicle(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.AddMaintenanceRecord(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateMaintenanceRecord(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.CompleteMaintenanceRecord(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UploadManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DownloadManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DeleteMaintenanceRecord(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.AnalyzeMaintenanceManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DeleteManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.CompleteItv(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateItv(getIt<VehicleRepository>()));

  // 🔹 OBD
  getIt.registerLazySingleton(() => usecases.ConnectOBD(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.GetParameterData(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.GetDiagnosticTroubleCodes(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.InitializeOBD(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.DisconnectOBD(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.GetSupportedPids(getIt<OBDRepository>()));
  
  // 🔹 Trip (Viajes)
  getIt.registerLazySingleton(() => usecases.InitializeTrip(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.StartTrip(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.EndTrip(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateTripDistance(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.GetCurrentTrip(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateMaintenanceRecordDistance(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.GetVehicleStats(getIt<TripRepository>()));
  getIt.registerLazySingleton(() => usecases.GetUserStatistics(getIt<TripRepository>(), getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdatePeriodicTrip(getIt<TripRepository>()));
  
  // 🔹 Fuel (Combustible)
  getIt.registerLazySingleton(() => usecases.GetGeneralFuelPrices(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.GetNearbyStations(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.GetFavoriteStations(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.AddFavoriteStation(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.RemoveFavoriteStation(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.GetStationDetails(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.SearchStations(getIt<FuelRepository>()));
  getIt.registerLazySingleton(() => usecases.InitializeFuelRepository(getIt<FuelRepository>()));

  // ───────────────────────────────────────────
  // BLoCs
  // ───────────────────────────────────────────
  getIt.registerLazySingleton(() => AuthBloc(
    loginUser: getIt<usecases.LoginUser>(),
    registerUser: getIt<usecases.RegisterUser>(),
    getUserData: getIt<usecases.GetUserData>(),
    changePassword: getIt<usecases.ChangePassword>(),
    logoutUser: getIt<usecases.LogoutUser>(),
    initializeRepositories: getIt<usecases.InitializeRepositories>(),
    homeBloc: getIt<HomeBloc>(),
    manualBloc: getIt<ManualBloc>(),
    chatBloc: getIt<ChatBloc>(),
    tripBloc: getIt<TripBloc>(),
  ));

  getIt.registerFactory(() => VehicleBloc(
    initializeVehicle: getIt<usecases.InitializeVehicle>(),
    getVehicles: getIt<usecases.GetVehicles>(),
    addVehicle: getIt<usecases.AddVehicle>(),
    updateVehicle: getIt<usecases.UpdateVehicle>(),
    deleteVehicle: getIt<usecases.DeleteVehicle>(),
    addMaintenanceRecord: getIt<usecases.AddMaintenanceRecord>(),
    updateMaintenanceRecord: getIt<usecases.UpdateMaintenanceRecord>(),
    completeMaintenanceRecord: getIt<usecases.CompleteMaintenanceRecord>(),
    uploadManual: getIt<usecases.UploadManual>(),
    downloadManual: getIt<usecases.DownloadManual>(),
    deleteMaintenanceRecord: getIt<usecases.DeleteMaintenanceRecord>(),
    analyzeMaintenanceManual: getIt<usecases.AnalyzeMaintenanceManual>(),
    deleteManual: getIt<usecases.DeleteManual>(),
    updateManual: getIt<usecases.UpdateManual>(),
    updateItv: getIt<usecases.UpdateItv>(),
    completeItv: getIt<usecases.CompleteItv>(),
  )..add(LoadVehicles())); // Carga inicial de vehículos

  getIt.registerFactory(() => ChatBloc(
    getOrCreateChat: getIt<usecases.GetOrCreateChat>(),
    createChat: getIt<usecases.CreateChat>(),
    addMessage: getIt<usecases.AddMessage>(),
    clearChat: getIt<usecases.ClearChat>(),
    initializeRepositories: getIt<usecases.InitializeRepositories>(),
  ));

  getIt.registerLazySingleton(() => ThemeBloc(getIt<SharedPreferences>()));
  getIt.registerLazySingleton(() => BluetoothBloc());

  getIt.registerFactory(() => ManualBloc(
    vehicleRepository: getIt<VehicleRepository>(),
  ));

  getIt.registerFactory(() => OBDBloc(
    initializeOBD: getIt<usecases.InitializeOBD>(),
    connectOBD: getIt<usecases.ConnectOBD>(),
    disconnectOBD: getIt<usecases.DisconnectOBD>(),
    getParameterData: getIt<usecases.GetParameterData>(),
    getDiagnosticTroubleCodes: getIt<usecases.GetDiagnosticTroubleCodes>(),
    getSupportedPids: getIt<usecases.GetSupportedPids>(),
  ));
  
  getIt.registerFactory(() => TripBloc(
    initializeTrip: getIt<usecases.InitializeTrip>(),
    startTrip: getIt<usecases.StartTrip>(),
    endTrip: getIt<usecases.EndTrip>(),
    //updateTripDistance: getIt<usecases.UpdateTripDistance>(),
    getCurrentTrip: getIt<usecases.GetCurrentTrip>(),
    //updateMaintenanceRecordDistance: getIt<usecases.UpdateMaintenanceRecordDistance>(),
    getVehicleStats: getIt<usecases.GetVehicleStats>(),
    updatePeriodicTrip: getIt<usecases.UpdatePeriodicTrip>(),
  )..add(InitializeTripSystem()));
  
  getIt.registerFactory(() => HomeBloc(
    getUserStatistics: getIt<usecases.GetUserStatistics>(),
  )..add(const LoadUserStatistics()));
  
  getIt.registerFactory(() => FuelBloc(
    getGeneralFuelPrices: getIt<usecases.GetGeneralFuelPrices>(),
    getNearbyStations: getIt<usecases.GetNearbyStations>(),
    getFavoriteStations: getIt<usecases.GetFavoriteStations>(),
    addFavoriteStation: getIt<usecases.AddFavoriteStation>(),
    removeFavoriteStation: getIt<usecases.RemoveFavoriteStation>(),
    getStationDetails: getIt<usecases.GetStationDetails>(),
    searchStations: getIt<usecases.SearchStations>(),
    initializeFuelRepository: getIt<usecases.InitializeFuelRepository>(),
  ));
}

// ───────────────────────────────────────────
// Reset del Service Locator
// ───────────────────────────────────────────
Future<void> resetServiceLocator() async {
  await getIt.reset();
  await setupServiceLocator();
}
