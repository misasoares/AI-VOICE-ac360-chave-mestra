import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/lead_profile.dart';
import '../../domain/repositories/lead_profile_repository.dart';

class LeadProfileRepositoryImpl implements LeadProfileRepository {
  static const String _storageKey = 'lead_profiles';

  @override
  Future<List<LeadProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => LeadProfile.fromJson(json)).toList();
  }

  @override
  Future<void> saveProfile(LeadProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();

    // Check if profile exists and update, or add new
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    final jsonList = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  @override
  Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();

    profiles.removeWhere((p) => p.id == id);

    final jsonList = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}
