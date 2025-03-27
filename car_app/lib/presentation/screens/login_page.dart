import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:car_app/presentation/blocs/blocs.dart';
import '../../config/theme/auth_custom_paint.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthSuccess) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              // Fondo con CustomPaint
              CustomPaint(
                painter: AuthBackgroundPainter(
                  primaryColor: theme.colorScheme.primary,
                ),
                size: size,
              ),
              
              // Contenido
              SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // Logo
                      Icon(
                        Icons.car_repair,
                        size: 80,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Car App',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Formulario en tarjeta con forma personalizada
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: IntrinsicHeight(
                          child: CustomPaint(
                            painter: AuthCardPainter(
                              isDarkMode: Theme.of(context).brightness == Brightness.dark,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Login',
                                        style: theme.textTheme.displaySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          hintText: 'Email',
                                          prefixIcon: const Icon(Icons.email),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value?.isEmpty ?? true) {
                                            return 'Por favor, ingresa tu email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          hintText: 'Contraseña',
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() => _obscurePassword = !_obscurePassword);
                                            },
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value?.isEmpty ?? true) {
                                            return 'Por favor, ingresa tu contraseña';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 30),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: state is AuthLoading
                                              ? null
                                              : () {
                                                  if (_formKey.currentState?.validate() ?? false) {
                                                    context.read<AuthBloc>().add(
                                                          LoginRequested(
                                                            _emailController.text,
                                                            _passwordController.text,
                                                          ),
                                                        );
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            foregroundColor: theme.colorScheme.onPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: state is AuthLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Text('Login'),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pushNamed(context, '/register');
                                          },
                                          child: Text(
                                            '¿No tienes cuenta? Regístrate',
                                            style: theme.textTheme.labelLarge?.copyWith(
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 