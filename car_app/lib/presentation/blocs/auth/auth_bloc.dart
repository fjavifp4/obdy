import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/usecases.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../presentation/blocs/service_locator.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final GetUserData _getUserData;
  final ChangePassword _changePassword;
  final LogoutUser _logoutUser;
  final InitializeRepositories _initializeRepositories;

  AuthBloc({
    required LoginUser loginUser,
    required RegisterUser registerUser,
    required GetUserData getUserData,
    required ChangePassword changePassword,
    required LogoutUser logoutUser,
    required InitializeRepositories initializeRepositories,
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
        await _initializeRepositories(user.token);
        emit(AuthSuccess(user: user, token: user.token, userId: user.id));
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
        await _initializeRepositories(token);
        
        final userDataResult = await _getUserData();
        await userDataResult.fold(
          (userFailure) async {
            emit(AuthError(
              'Registro exitoso, pero error al obtener datos del usuario: ${userFailure.message}'
            ));
          },
          (user) async {
            emit(AuthSuccess(user: user, token: token, userId: user.id));
          },
        );
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
