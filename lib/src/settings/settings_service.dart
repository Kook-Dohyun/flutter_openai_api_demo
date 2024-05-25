import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  static const String _boxName = "settingsBox";
  static const String _apiKeys = "apiKeys"; // API 키들을 저장할 키
  static const String _currentApiKey = "apiKey"; // 현재 API 키
  static const String _baseUrl = "baseUrl";
  static const String _apiVersion = "apiVersion";
  static const String _themeModeKey = "themeMode";
  static const String _openedExpansionTile = 'openedExpansionTile';

  Box<dynamic>? _settingsBox;

  Future<void> initHive() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(_boxName);
  }

  /// API 키 리스트에서 모든 키를 불러옵니다.
  List<String> getApiKeys() {
    return List<String>.from(
        _settingsBox?.get(_apiKeys, defaultValue: []) ?? []);
  }

  /// 새 API 키를 리스트에 추가합니다.
  Future<void> addApiKey(String apiKey) async {
    var apiKeys = getApiKeys();
    apiKeys.add(apiKey);
    await _settingsBox?.put(_apiKeys, apiKeys);
    if (apiKeys.length == 1) {
      // 첫 키라면 현재 API 키로 설정
      await setCurrentApiKey(apiKey);
    }
  }

  /// API 키를 삭제하고 첫 번째 키를 현재 API 키로 설정합니다.
  Future<void> removeApiKey(String apiKey) async {
    var apiKeys = getApiKeys();
    apiKeys.remove(apiKey);
    await _settingsBox?.put(_apiKeys, apiKeys);
    if (apiKeys.isNotEmpty) {
      await setCurrentApiKey(apiKeys.first); // 리스트의 첫 번째 키를 현재 키로 설정
    } else {
      await _settingsBox?.delete(_currentApiKey); // 모든 키가 삭제되면 현재 키도 삭제
    }
  }

  Future<String?> getCurrentApiKey() async {
    return _settingsBox?.get(_currentApiKey);
  }

  Future<void> setCurrentApiKey(String? apiKey) async {
    await _settingsBox?.put(_currentApiKey, apiKey);
  }

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

  /// 사용자의 선호 테마 모드를 불러옵니다.
  Future<ThemeMode> getThemeMode() async {
    String? themeStr = _settingsBox?.get(_themeModeKey) as String?;
    return themeStr == 'ThemeMode.dark'
        ? ThemeMode.dark
        : themeStr == 'ThemeMode.light'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  /// 테마 모드를 저장합니다.
  Future<void> setThemeMode(ThemeMode theme) async {
    await _settingsBox?.put(_themeModeKey, theme.toString());
  }

  Future<bool> getOpenedExpansionTile() async {
    String? isOpend = _settingsBox?.get(_openedExpansionTile) as String?;

    return isOpend == 'true' ? true : false;
  }

  Future<void> setOpenedExpansionTileState(bool value) async {
    String str = value == true ? 'true' : 'false';
    await _settingsBox?.put(_openedExpansionTile, str);
    var d = _settingsBox?.get(_openedExpansionTile);
    print('update!:$d');
  }
}
