import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/partner_summary.dart';
import '../domain/partners_repository.dart';
import '../infrastructure/api/api_partners_repository.dart';
final partnersRepositoryProvider=Provider<PartnersRepository>(
 (ref)=>ApiPartnersRepository(ref.watch(authenticatedApiClientProvider)));
final partnersProvider=FutureProvider<List<PartnerSummary>>((ref)=>ref.watch(partnersRepositoryProvider).list());
