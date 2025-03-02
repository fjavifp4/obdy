import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Implementaciones
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/vehicle_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/obd_repository_mock.dart';

// Interfaces
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/obd_repository.dart';

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
  getIt.registerLazySingleton<OBDRepository>(() => OBDRepositoryMock());        

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
  getIt.registerLazySingleton(() => usecases.UploadManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DownloadManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DeleteMaintenanceRecord(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.AnalyzeMaintenanceManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.DeleteManual(getIt<VehicleRepository>()));
  getIt.registerLazySingleton(() => usecases.UpdateManual(getIt<VehicleRepository>()));

  // 🔹 OBD
  getIt.registerLazySingleton(() => usecases.ConnectOBD(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.GetParameterData(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.GetDiagnosticTroubleCodes(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.InitializeOBD(getIt<OBDRepository>()));
  getIt.registerLazySingleton(() => usecases.DisconnectOBD(getIt<OBDRepository>()));

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
  ));

  getIt.registerFactory(() => VehicleBloc(
    initializeVehicle: getIt<usecases.InitializeVehicle>(),
    getVehicles: getIt<usecases.GetVehicles>(),
    addVehicle: getIt<usecases.AddVehicle>(),
    updateVehicle: getIt<usecases.UpdateVehicle>(),
    deleteVehicle: getIt<usecases.DeleteVehicle>(),
    addMaintenanceRecord: getIt<usecases.AddMaintenanceRecord>(),
    updateMaintenanceRecord: getIt<usecases.UpdateMaintenanceRecord>(),
    uploadManual: getIt<usecases.UploadManual>(),
    downloadManual: getIt<usecases.DownloadManual>(),
    deleteMaintenanceRecord: getIt<usecases.DeleteMaintenanceRecord>(),
    analyzeMaintenanceManual: getIt<usecases.AnalyzeMaintenanceManual>(),
    deleteManual: getIt<usecases.DeleteManual>(),
    updateManual: getIt<usecases.UpdateManual>(),
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
  ));
}

// ───────────────────────────────────────────
// Reset del Service Locator
// ───────────────────────────────────────────
Future<void> resetServiceLocator() async {
  await getIt.reset();
  await setupServiceLocator();
}
