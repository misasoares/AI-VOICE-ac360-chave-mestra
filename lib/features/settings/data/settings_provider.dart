import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String?>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ApiKeyNotifier(storageService);
});

class ApiKeyNotifier extends StateNotifier<String?> {
  final StorageService _storageService;

  ApiKeyNotifier(this._storageService) : super(_storageService.getApiKey());

  Future<void> setApiKey(String apiKey) async {
    await _storageService.setApiKey(apiKey);
    state = apiKey;
  }
}
