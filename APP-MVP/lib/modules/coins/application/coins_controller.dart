import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/coin_overview.dart';
import '../domain/coins_repository.dart';
import '../infrastructure/api/api_coins_repository.dart';
final coinsRepositoryProvider=Provider<CoinsRepository>(
 (ref)=>ApiCoinsRepository(ref.watch(authenticatedApiClientProvider)));
final coinOverviewProvider=FutureProvider<CoinOverview>((ref)=>ref.watch(coinsRepositoryProvider).overview());
