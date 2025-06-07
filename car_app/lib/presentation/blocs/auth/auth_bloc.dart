import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/usecases.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../presentation/blocs/service_locator.dart';
import '../blocs.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final GetUserData _getUserData;
  final ChangePassword _changePassword;
  final LogoutUser _logoutUser;
  final InitializeRepositories _initializeRepositories;
  
  // Referencias a otros BLoCs
  final HomeBloc homeBloc;
  final ManualBloc manualBloc;
  final ChatBloc chatBloc;
  final TripBloc tripBloc;

  AuthBloc({
    required LoginUser loginUser,
    required RegisterUser registerUser,
    required GetUserData getUserData,
    required ChangePassword changePassword,
    required LogoutUser logoutUser,
    required InitializeRepositories initializeRepositories,
    required this.homeBloc,
    required this.manualBloc,
    required this.chatBloc,
    required this.tripBloc,
  }) : _loginUser = loginUser,
       _registerUser = registerUser,
       _getUserData = getUserData,
       _changePassword = changePassword,
       _logoutUser = logoutUser,
       _initializeRepositories = initializeRepositories,
       super(AuthInitial()) {
    on<LoginRequested>(_handleLogin);
    on<RegisterRequested>(_handleRegister);
    on<LogoutRequested>(_handleLogout);
    on<GetUserDataRequested>(_handleGetUserData);
    on<ChangePasswordRequested>(_handleChangePassword);
    on<InitializeApp>(_handleInitializeApp);
    on<AuthenticationSuccess>(_onAuthenticationSuccess);
  }
  
  // Nuevo manejador para el evento de éxito de autenticación
  Future<void> _onAuthenticationSuccess(
    AuthenticationSuccess event,
    Emitter<AuthState> emit
  ) async {
    await _initializeRepositories(event.token);
    
    // Notificar a otros BLoCs para que se reinicien
    homeBloc.add(const RefreshHomeData());
    manualBloc.add(InitializeManual(event.token));
    tripBloc.add(InitializeTripSystem());
    
    // Obtener los datos del usuario para completar el estado
    final userDataResult = await _getUserData();
    await userDataResult.fold(
      (userFailure) async {
        emit(AuthError('Autenticación exitosa, pero error al obtener datos del usuario: ${userFailure.message}'));
      },
      (user) async {
        emit(AuthSuccess(user: user, token: event.token, userId: user.id));
      }
    );
  }

  Future<void> _handleLogin(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _loginUser(event.email, event.password);
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (user) async {
        // En lugar de hacer todo aquí, disparamos el evento de éxito
        add(AuthenticationSuccess(user.token));
      },
    );
  }

  Future<void> _handleRegister(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _registerUser(
      event.username,
      event.email,
      event.password,
    );
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (token) async {
        // En lugar de hacer todo aquí, disparamos el evento de éxito
        add(AuthenticationSuccess(token));
      },
    );
  }

  Future<void> _handleLogout(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _logoutUser();
    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (_) async {
        await resetServiceLocator();
        emit(AuthInitial());
        event.onLogoutSuccess?.call();
      },
    );
  }

  Future<void> _handleGetUserData(
    GetUserDataRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthSuccess) return;

    final result = await _getUserData();
    await result.fold(
      (failure) async {
        if (state is AuthSuccess) {
          emit(state);
        }
      },
      (user) async {
        final currentState = state as AuthSuccess;
        emit(AuthSuccess(
          user: user,
          token: currentState.token,
          userId: user.id,
        ));
      },
    );
  }

  Future<void> _handleChangePassword(
    ChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _changePassword(
      event.currentPassword,
      event.newPassword,
    );
    await result.fold(
      (failure) async {
        emit(AuthError(failure.message));
        if (state is AuthSuccess) {
          emit(state);
        }
      },
      (_) async {
        if (state is AuthSuccess) {
          emit(state);
        }
      },
    );
  }

  Future<void> _handleInitializeApp(
    InitializeApp event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _getUserData();
    await result.fold(
      (failure) async => emit(AuthError('No hay sesión activa')),
      (user) async => emit(AuthSuccess(
        user: user,
        token: user.token,
        userId: user.id,
      )),
    );
  }
} 
