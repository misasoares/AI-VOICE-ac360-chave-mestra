import '../entities/lead_profile.dart';

abstract class LeadProfileRepository {
  Future<List<LeadProfile>> getProfiles();
  Future<void> saveProfile(LeadProfile profile);
  Future<void> deleteProfile(String id);
}
