import '../entities/simulation_result.dart';

abstract class ISimulationRepository {
  Future<void> saveSimulation(SimulationResult result);
  Future<List<SimulationResult>> getSimulations();
}
