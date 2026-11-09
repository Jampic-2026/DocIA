import 'admin_console.dart';
abstract interface class AdminConsoleRepository {Future<AdminOverview> overview();Future<void> updateStatus(String id,String status,{String? reason});Future<void> updateRoles(String id,List<String> roles);Future<List<SystemSetting>> settings();Future<void> updateSetting(String key,Object? value,{String? description});}
