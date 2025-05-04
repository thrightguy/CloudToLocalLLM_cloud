import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../services/tunnel_service.dart';
import '../services/ollama_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService storageService;
  final TunnelService tunnelService;
  final OllamaService ollamaService;

  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';

  // Settings
  ThemeMode _themeMode = ThemeMode.system;
  String _llmProvider = AppConfig.defaultLlmProvider;
  bool _enableCloudSync = AppConfig.enableCloudSync;
  bool _enableOfflineMode = AppConfig.enableOfflineMode;
  bool _enableModelDownload = AppConfig.enableModelDownload;
  bool _enableTunnel = false;
  String? _ollamaIpAddress;
  String? _lmStudioIpAddress;
  String? _customLlmIpAddress;
  String? _ngrokAuthToken;
  String? _ngrokSubdomain;
  bool _isTunnelEnabled = false;
  bool _isFirstLaunch = true;

  SettingsProvider({
    required this.storageService,
    required this.tunnelService,
    required this.ollamaService,
  }) {
    initialize();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  ThemeMode get themeMode => _themeMode;
  String get llmProvider => _llmProvider;
  bool get enableCloudSync => _enableCloudSync;
  bool get enableOfflineMode => _enableOfflineMode;
  bool get enableModelDownload => _enableModelDownload;
  bool get enableTunnel => _enableTunnel;
  bool get isTunnelConnected => tunnelService.isConnected.value;
  String get tunnelUrl => tunnelService.tunnelUrl.value;
  String? get ollamaIpAddress => _ollamaIpAddress;
  String? get lmStudioIpAddress => _lmStudioIpAddress;
  String? get customLlmIpAddress => _customLlmIpAddress;
  String? get ngrokAuthToken => _ngrokAuthToken;
  String? get ngrokSubdomain => _ngrokSubdomain;
  bool get isTunnelEnabled => _isTunnelEnabled;
  bool get isFirstLaunch => _isFirstLaunch;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    _setLoading(true);
    try {
      await _loadSettings();
      tunnelService.isConnected.addListener(_onTunnelStatusChanged);
      tunnelService.tunnelUrl.addListener(_onTunnelUrlChanged);
      _isInitialized = true;
      _error = '';
    } catch (e) {
      _error = 'Error initializing settings provider: $e';
      debugPrint(_error);
      // Use defaults
      _themeMode = ThemeMode.system;
      _llmProvider = AppConfig.defaultLlmProvider;
      _enableCloudSync = AppConfig.enableCloudSync;
      _enableOfflineMode = AppConfig.enableOfflineMode;
      _enableModelDownload = AppConfig.enableModelDownload;
      _enableTunnel = false;
      _ollamaIpAddress = null;
      _lmStudioIpAddress = null;
      _customLlmIpAddress = null;
      _ngrokAuthToken = null;
      _ngrokSubdomain = null;
      _isTunnelEnabled = false;
      _isFirstLaunch = true;
    } finally {
      _setLoading(false);
    }
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final settings = await storageService.getSettings();

      // Theme mode
      final themeModeStr = settings['themeMode'] as String? ?? 'system';
      _themeMode = _parseThemeMode(themeModeStr);

      // LLM provider
      _llmProvider =
          settings['llmProvider'] as String? ?? AppConfig.defaultLlmProvider;

      // Feature flags
      _enableCloudSync =
          settings['enableCloudSync'] as bool? ?? AppConfig.enableCloudSync;
      _enableOfflineMode =
          settings['enableOfflineMode'] as bool? ?? AppConfig.enableOfflineMode;
      _enableModelDownload = settings['enableModelDownload'] as bool? ??
          AppConfig.enableModelDownload;
      _enableTunnel = settings['enableTunnel'] as bool? ?? false;

      // Additional settings
      _ollamaIpAddress = settings['ollamaIpAddress'] as String?;
      _lmStudioIpAddress = settings['lmStudioIpAddress'] as String?;
      _customLlmIpAddress = settings['customLlmIpAddress'] as String?;
      _ngrokAuthToken = settings['ngrokAuthToken'] as String?;
      _ngrokSubdomain = settings['ngrokSubdomain'] as String?;
      _isTunnelEnabled = settings['isTunnelEnabled'] as bool? ?? false;
      _isFirstLaunch = settings['isFirstLaunch'] as bool? ?? true;

      // Start tunnel if enabled
      if (_enableTunnel) {
        await _startTunnel();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Use defaults
      _themeMode = ThemeMode.system;
      _llmProvider = AppConfig.defaultLlmProvider;
      _enableCloudSync = AppConfig.enableCloudSync;
      _enableOfflineMode = AppConfig.enableOfflineMode;
      _enableModelDownload = AppConfig.enableModelDownload;
      _enableTunnel = false;
      _ollamaIpAddress = null;
      _lmStudioIpAddress = null;
      _customLlmIpAddress = null;
      _ngrokAuthToken = null;
      _ngrokSubdomain = null;
      _isTunnelEnabled = false;
      _isFirstLaunch = true;
    }
  }

  // Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final settings = {
        'themeMode': _themeModeToString(_themeMode),
        'llmProvider': _llmProvider,
        'enableCloudSync': _enableCloudSync,
        'enableOfflineMode': _enableOfflineMode,
        'enableModelDownload': _enableModelDownload,
        'enableTunnel': _enableTunnel,
        'ollamaIpAddress': _ollamaIpAddress,
        'lmStudioIpAddress': _lmStudioIpAddress,
        'customLlmIpAddress': _customLlmIpAddress,
        'ngrokAuthToken': _ngrokAuthToken,
        'ngrokSubdomain': _ngrokSubdomain,
        'isTunnelEnabled': _isTunnelEnabled,
        'isFirstLaunch': _isFirstLaunch,
      };

      await storageService.saveSettings(settings);
    } catch (e) {
      debugPrint('Error saving settings: $e');
      _error = 'Failed to save settings.';
      notifyListeners();
    }
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
    debugPrint('Theme mode set to: $mode');
  }

  // Set LLM provider
  Future<void> setLlmProvider(String provider) async {
    if (_llmProvider == provider) return;
    _llmProvider = provider;
    await _saveSettings();
    try {
      final newBaseUrl = provider == 'lmstudio'
          ? AppConfig.lmStudioBaseUrl
          : AppConfig.ollamaBaseUrl;
      ollamaService.updateBaseUrl(newBaseUrl);
    } catch (e) {
      debugPrint('Error updating OllamaService base URL: $e');
    }
    notifyListeners();
    debugPrint('LLM provider set to: $provider');
  }

  // Set cloud sync
  Future<void> setEnableCloudSync(bool enable) async {
    _enableCloudSync = enable;
    await _saveSettings();
    notifyListeners();
    debugPrint('Cloud sync set to: $enable');
  }

  // Set offline mode
  Future<void> setEnableOfflineMode(bool enable) async {
    _enableOfflineMode = enable;
    await _saveSettings();
    notifyListeners();
    debugPrint('Offline mode set to: $enable');
  }

  // Set model download
  Future<void> setEnableModelDownload(bool enable) async {
    _enableModelDownload = enable;
    await _saveSettings();
    notifyListeners();
    debugPrint('Model download set to: $enable');
  }

  // Set tunnel
  Future<void> setEnableTunnel(bool enable) async {
    if (_enableTunnel == enable) return;
    _enableTunnel = enable;
    if (enable) {
      final success = await _startTunnel();
      if (!success) {
        _enableTunnel = false;
        _error = 'Failed to start tunnel. Please check configuration.';
      } else {
        _error = '';
      }
    } else {
      await _stopTunnel();
      _error = '';
    }
    await _saveSettings();
    notifyListeners();
    debugPrint('Tunnel enabled set to: $enable');
  }

  // Start the tunnel
  Future<bool> _startTunnel() async {
    try {
      return await tunnelService.startTunnel();
    } catch (e) {
      debugPrint('Error starting tunnel: $e');
      return false;
    }
  }

  // Stop the tunnel
  Future<void> _stopTunnel() async {
    try {
      await tunnelService.stopTunnel();
    } catch (e) {
      debugPrint('Error stopping tunnel: $e');
    }
  }

  // Check tunnel status
  Future<bool> checkTunnelStatus() async {
    try {
      return await tunnelService.checkTunnelStatus();
    } catch (e) {
      debugPrint('Error checking tunnel status: $e');
      return false;
    }
  }

  // Reset settings to defaults
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _llmProvider = AppConfig.defaultLlmProvider;
    _enableCloudSync = AppConfig.enableCloudSync;
    _enableOfflineMode = AppConfig.enableOfflineMode;
    _enableModelDownload = AppConfig.enableModelDownload;
    _enableTunnel = false;
    _ollamaIpAddress = null;
    _lmStudioIpAddress = null;
    _customLlmIpAddress = null;
    _ngrokAuthToken = null;
    _ngrokSubdomain = null;
    _isTunnelEnabled = false;
    _isFirstLaunch = true;

    // Stop tunnel if it's running
    if (_enableTunnel) {
      await _stopTunnel();
    }

    await _saveSettings();
    notifyListeners();
  }

  // Handle tunnel status changes
  void _onTunnelStatusChanged() {
    notifyListeners();
  }

  // Handle tunnel URL changes
  void _onTunnelUrlChanged() {
    notifyListeners();
  }

  // Helper to parse theme mode from string
  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    tunnelService.isConnected.removeListener(_onTunnelStatusChanged);
    tunnelService.tunnelUrl.removeListener(_onTunnelUrlChanged);
    super.dispose();
  }
}
