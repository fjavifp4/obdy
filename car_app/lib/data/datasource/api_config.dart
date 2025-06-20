/// Configuración para la API REST
class ApiConfig {
  /// URL base para las solicitudes a la API
  
  //static const String baseUrl = 'http://192.168.1.130:8000';
  //static const String baseUrl = 'https://tfg-cyan.vercel.app';
  static const String baseUrl = 'https://obdy.onrender.com';
  
  // Rutas específicas
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String vehiclesEndpoint = '/vehicles';
  static const String chatsEndpoint = '/chats';
  static const String tripsEndpoint = '/trips';
} 
