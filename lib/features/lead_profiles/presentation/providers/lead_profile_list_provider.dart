import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead_profile.dart';
import 'lead_profile_repository_provider.dart';

final leadProfileListProvider = FutureProvider<List<LeadProfile>>((ref) async {
  final repository = ref.watch(leadProfileRepositoryProvider);
  return repository.getProfiles();
});
