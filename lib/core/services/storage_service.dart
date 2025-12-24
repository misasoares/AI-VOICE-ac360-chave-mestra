import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) => throw UnimplementedError());

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _apiKeyKey = 'openai_api_key';

  Future<void> setApiKey(String apiKey) async {
    await _prefs.setString(_apiKeyKey, apiKey);
  }

  String? getApiKey() {
    return _prefs.getString(_apiKeyKey);
  }
}
