import 'package:flutter_riverpod/flutter_riverpod.dart';import '../../../core/network/api_client_provider.dart';import '../domain/admin_console.dart';import '../domain/admin_console_repository.dart';import '../infrastructure/api/api_admin_console_repository.dart';
final adminConsoleRepositoryProvider=Provider<AdminConsoleRepository>((ref)=>ApiAdminConsoleRepository(ref.watch(authenticatedApiClientProvider)));
final adminOverviewProvider=FutureProvider<AdminOverview>((ref)=>ref.watch(adminConsoleRepositoryProvider).overview());
final systemSettingsProvider=FutureProvider<List<SystemSetting>>((ref)=>ref.watch(adminConsoleRepositoryProvider).settings());
