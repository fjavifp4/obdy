import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente para hacer llamadas API al backend
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final SharedPreferences _prefs;
  
  ApiClient({
    required this.baseUrl,
    required SharedPreferences prefs,
    http.Client? httpClient,
  }) : 
    _httpClient = httpClient ?? http.Client(),
    _prefs = prefs;
  
  /// Realiza una petición GET
  Future<http.Response> get(String endpoint, {Map<String, String>? queryParameters}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);
    final headers = await _getHeaders();
    
    return _httpClient.get(uri, headers: headers);
  }
  
  /// Realiza una petición POST
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    return _httpClient.post(
      uri, 
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }
  
  /// Realiza una petición PUT
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    return _httpClient.put(
      uri, 
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }
  
  /// Realiza una petición DELETE
  Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    return _httpClient.delete(uri, headers: headers);
  }
  
  /// Obtiene los headers para las peticiones, incluyendo el token de autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = _prefs.getString('token');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  /// Cierra el cliente HTTP
  void dispose() {
    _httpClient.close();
  }
} 