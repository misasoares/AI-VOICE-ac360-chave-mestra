import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/repositories/simulation_repository.dart';
import 'repositories/simulation_repository_impl.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final simulationRepositoryProvider = Provider<ISimulationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SimulationRepositoryImpl(prefs);
});
