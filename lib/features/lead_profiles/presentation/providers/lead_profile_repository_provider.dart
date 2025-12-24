import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/lead_profile_repository_impl.dart';
import '../../domain/repositories/lead_profile_repository.dart';

final leadProfileRepositoryProvider = Provider<LeadProfileRepository>((ref) {
  return LeadProfileRepositoryImpl();
});
