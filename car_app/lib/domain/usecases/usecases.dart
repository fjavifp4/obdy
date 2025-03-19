// Auth usecases
export 'auth/login_user.dart';
export 'auth/register_user.dart';
export 'auth/get_user_data.dart';
export 'auth/change_password.dart';
export 'auth/logout_user.dart';

// Chat usecases
export 'chat/get_or_create_chat.dart';
export 'chat/create_chat.dart';
export 'chat/add_message.dart';
export 'chat/clear_chat.dart';

// Vehicle usecases
export 'vehicle/add_maintenance_record.dart';
export 'vehicle/add_vehicle.dart';
export 'vehicle/analyze_maintenance_manual.dart';
export 'vehicle/complete_itv.dart';
export 'vehicle/complete_maintenance_record.dart';
export 'vehicle/delete_maintenance_record.dart';
export 'vehicle/delete_manual.dart';
export 'vehicle/delete_vehicle.dart';
export 'vehicle/download_manual.dart';
export 'vehicle/get_vehicles.dart';
export 'vehicle/initialize_vehicle.dart';
export 'vehicle/update_itv.dart';
export 'vehicle/update_maintenance_record.dart';
export 'vehicle/update_manual.dart';
export 'vehicle/update_vehicle.dart';
export 'vehicle/upload_manual.dart';

// OBD usecases
export 'obd/initialize_obd.dart';
export 'obd/connect_obd.dart';
export 'obd/disconnect_obd.dart';
export 'obd/get_parameter_data.dart';
export 'obd/get_diagnostic_trouble_codes.dart';
//export 'obd/check_obd_connection.dart';

// Trip usecases
export 'trip/initialize_trip.dart';
export 'trip/start_trip.dart';
export 'trip/end_trip.dart';
export 'trip/update_trip_distance.dart';
export 'trip/get_current_trip.dart';
export 'trip/update_maintenance_record_distance.dart';
export 'trip/get_user_statistics.dart';
export 'trip/get_vehicle_stats.dart';

// Fuel usecases
export 'fuel/get_general_fuel_prices.dart';
export 'fuel/get_nearby_stations.dart';
export 'fuel/manage_favorite_stations.dart' hide SearchStations;
export 'fuel/get_station_details.dart';
export 'fuel/search_stations.dart';
export 'fuel/initialize_fuel_repository.dart';

// Repository initialization
export 'initialize_repositories.dart'; 