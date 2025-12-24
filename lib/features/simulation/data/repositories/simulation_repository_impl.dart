import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/simulation_result.dart';
import '../../domain/repositories/simulation_repository.dart';

class SimulationRepositoryImpl implements ISimulationRepository {
  final SharedPreferences _prefs;
  static const String _storageKey = 'simulation_history';

  SimulationRepositoryImpl(this._prefs);

  @override
  Future<List<SimulationResult>> getSimulations() async {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.map((e) => SimulationResult.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveSimulation(SimulationResult result) async {
    final simulations = await getSimulations();
    simulations.insert(0, result); // Add to top
    final jsonString = json.encode(simulations.map((e) => e.toMap()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }
}
