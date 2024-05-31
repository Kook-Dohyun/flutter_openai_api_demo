import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:openai/src/services/openai_client.dart';
import 'settings_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final OpenAiClient _openAiClient;

  User? _currentUser;
  late ThemeMode _themeMode;
  Color? _seedColor;
  List<String> _apiKeys = [];
  String? _apiKey;
  String? _baseUrl;
  String? _apiVersion;

  SettingsController(this._settingsService) {
    _auth.authStateChanges().listen(_updateLoginStatus);
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null; // 로그인 상태 가져오기
  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor!;
  ColorScheme get colorScheme => ColorScheme.fromSeed(seedColor: seedColor);
  List<String> get apiKeys => _apiKeys;
  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;
  String? get apiVersion => _apiVersion;
  OpenAiClient get openAiClient => _openAiClient;

  Future<void> loadSettings() async {
    await _settingsService.initHive(); // Initialize Hive
    _themeMode = await _settingsService.getThemeMode();
    _seedColor = await _settingsService.getSeedColor();
    _apiKeys = _settingsService.getApiKeys();
    _apiKey = await _settingsService.getCurrentApiKey();
    _baseUrl = await _settingsService.getBaseUrl();
    _apiVersion = await _settingsService.getApiVersion();
    _openAiClient = OpenAiClient(
      apiKey: _apiKey ?? '',
      apiVersion: _apiVersion ?? 'v1',
      baseUrl: _baseUrl ?? 'https://api.openai.com',
    );
    notifyListeners();
  }

  /// Login
  ////////////////////////////////////////////////////////////////
  void _updateLoginStatus(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<UserCredential> googleSignIn() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> googleSignOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    _updateLoginStatus(null);
  }

  ////////////////////////////////////////////////////////////////
  Future<void> firebasedeleteDoc(apiKey) async {
    await _firestore.collection(_currentUser!.uid).doc(apiKey).delete();
  }

  /// Theme
  ////////////////////////////////////////////////////////////////
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode != _themeMode) {
      _themeMode = newThemeMode;
      await _settingsService.setThemeMode(newThemeMode);
      notifyListeners();
    }
  }

  Future<void> updateSeedColorKey(String seedColorKey) async {
    await _settingsService.setSeedColor(seedColorKey);
    notifyListeners();
  }

  ////////////////////////////////////////////////////////////////
  Future<bool> updateApiKey(String newApiKey) async {
    if (newApiKey.isEmpty) return false;
    bool isValid = await getModelListForValidateApiKey(newApiKey);
    if (isValid) {
      _openAiClient.updateApiKey(newApiKey);
      await _settingsService.addApiKey(newApiKey);
      _apiKeys = _settingsService.getApiKeys();
      setCurrentApiKey(newApiKey);
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  Future<void> updateBaseUrl(String newBaseUrl) async {
    _baseUrl = newBaseUrl;
    _openAiClient.updateBaseUrl(newBaseUrl);
    await _settingsService.setBaseUrl(newBaseUrl);
    notifyListeners();
  }

  Future<void> updateApiVersion(String newApiVersion) async {
    _apiVersion = newApiVersion;
    _openAiClient.updateApiVersion(newApiVersion);
    await _settingsService.setApiVersion(newApiVersion);
    notifyListeners();
  }

  Future<void> setCurrentApiKey(String? apiKey) async {
    await _settingsService.setCurrentApiKey(_apiKey);
    _apiKey = apiKey;

    notifyListeners();
  }

  Future<bool> removeApiKey(String apiKey) async {
    if (apiKey.isEmpty) return false;
    if (_apiKeys.contains(apiKey)) {
      // await firebasedeleteDoc(apiKey);
      await _settingsService.removeApiKey(apiKey);
      _apiKeys = _settingsService.getApiKeys();
      if (_apiKey == apiKey) {
        setCurrentApiKey(_apiKeys.isNotEmpty ? _apiKeys.first : null);
      }
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  Future<dynamic> getModelListForValidateApiKey(newApiKey) async {
    newApiKey ??= apiKey;
    try {
      final url = Uri.parse('https://api.openai.com/v1/models');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $newApiKey',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
