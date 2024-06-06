import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  static const String _boxName = "settingsBox";
  static const String _apiKeys = "apiKeys"; // API 키들을 저장할 키
  static const String _currentApiKey = "apiKey"; // 현재 API 키
  static const String _baseUrl = "baseUrl";
  static const String _apiVersion = "apiVersion";
  static const String _themeModeKey = "themeMode";
  static const String _seedColorKey = "seedColorKey";

  Box<dynamic>? _settingsBox;

  Future<void> initHive() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(_boxName);
  }
 
  List<String> getApiKeys() {
    return List<String>.from(_settingsBox?.get(_apiKeys, defaultValue: []));
  }

   Future<void> setApiKeys(List<String>? apiKeys) async{
    await _settingsBox?.put(_apiKeys, apiKeys);
  }

  Future<String?> getCurrentApiKey() async {
    return _settingsBox?.get(_currentApiKey);
  }

  Future<void> setCurrentApiKey(String? apiKey) async {
    await _settingsBox?.put(_currentApiKey, apiKey);
  }

   Future<void> addApiKey(String apiKey) async {
    List<String> apiKeys = getApiKeys();
    if (apiKeys.contains(apiKey)) {
    } else {
      apiKeys.add(apiKey);
    }
    await _settingsBox?.put(_apiKeys, apiKeys);

    await setCurrentApiKey(apiKey);
  }

    Future<void> removeApiKey(String apiKey) async {
    var apiKeys = getApiKeys();
    apiKeys.remove(apiKey);
    await _settingsBox?.put(_apiKeys, apiKeys);
    if (apiKeys.isNotEmpty) {
      await setCurrentApiKey(apiKeys.first);  
    } else {
      await _settingsBox?.delete(_currentApiKey); 
    }
  }

  /////////////////////////////////////////////////////////////
  Future<String?> getBaseUrl() async {
    return _settingsBox?.get(_baseUrl, defaultValue: 'https://api.openai.com');
  }

  Future<void> setBaseUrl(String? baseUrl) async {
    await _settingsBox?.put(_baseUrl, baseUrl);
  }

  Future<String?> getApiVersion() async {
    return _settingsBox?.get(_apiVersion, defaultValue: 'v1');
  }

  Future<void> setApiVersion(String? apiVersion) async {
    await _settingsBox?.put(_apiVersion, apiVersion);
  }

  Future<ThemeMode> getThemeMode() async {
    String? themeStr = _settingsBox?.get(_themeModeKey) as String?;
    return themeStr == 'ThemeMode.dark'
        ? ThemeMode.dark
        : themeStr == 'ThemeMode.light'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode theme) async {
    await _settingsBox?.put(_themeModeKey, theme.toString());
  }

  Future<void> setSeedColor(String seedColorKey) async {
    await _settingsBox?.put(_seedColorKey, seedColorKey);
  }

  final Map<String, Color> colorMap = {
    'blue': Colors.blue,
    'purple': Colors.deepPurple,
    'pink': Colors.pink,
    'green': Colors.greenAccent,
  };
  Future<Color> getSeedColor() async {
    final seedColorKey = _settingsBox?.get(_seedColorKey, defaultValue: 'blue');
    return colorMap[seedColorKey]!;
  }
}
