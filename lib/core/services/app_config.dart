import '../constants/app_constants.dart';

/// 🔧 App Configuration - Backend URLs & Environments

class AppEnvironment {
  final String name;
  final String apiUrl;
  final String wsUrl;
  final bool debugLogging;
  final bool enableBotFallback;

  const AppEnvironment({
    required this.name,
    required this.apiUrl,
    required this.wsUrl,
    this.debugLogging = true,
    this.enableBotFallback = true,
  });
}

class AppConfig {
  static const Map<String, AppEnvironment> environments = {
    'development': AppEnvironment(
      name: 'Development (Local)',
      apiUrl: 'http://localhost:3000',
      wsUrl: 'ws://localhost:3000',
      debugLogging: true,
      enableBotFallback: true,
    ),
    'staging': AppEnvironment(
      name: 'Staging',
      apiUrl: 'http://staging.strangchatomy.app:3000',
      wsUrl: 'ws://staging.strangchatomy.app:3000',
      debugLogging: true,
      enableBotFallback: true,
    ),
    'production': AppEnvironment(
      name: 'Production',
      apiUrl: 'https://strangchatomy.online',
      wsUrl: 'wss://strangchatomy.online/ws',
      debugLogging: false,
      enableBotFallback: true,
    ),
    'custom': AppEnvironment(
      name: 'Custom Server',
      apiUrl: 'http://192.168.1.100:3000',
      wsUrl: 'ws://192.168.1.100:3000',
      debugLogging: true,
      enableBotFallback: true,
    ),
  };

  static const String ACTIVE_ENV = 'production';

  static AppEnvironment get current {
    final env = environments[ACTIVE_ENV];
    if (env == null) throw Exception('❌ Environment "$ACTIVE_ENV" not found');
    return env;
  }

  static String get apiUrl => current.apiUrl;
  static String get wsUrl => current.wsUrl;
  static bool get debugLogging => current.debugLogging;
  static bool get enableBotFallback => current.enableBotFallback;
  static String get envName => current.name;

  // ── Anonymous Session Endpoints (the only active endpoints) ─────────────
  static String get createSessionUrl => '$apiUrl/api/sessions/anonymous';
  static String get verifySessionUrl => '$apiUrl/api/sessions/anonymous/verify';
  static String get endSessionUrl    => '$apiUrl/api/sessions/anonymous/end';

  // ── Security: base HTTP headers for every API call ──────────────────────
  // X-App-Key is checked by the backend middleware on all /api/sessions/* routes.
  // Without it, the backend returns 403 Forbidden.
  static Map<String, String> get baseHeaders => {
    'Content-Type': 'application/json',
    'X-App-Key': AppConstants.appKey,
  };

  static void printConfig() {
    if (debugLogging) {
      print('═' * 70);
      print('🔧 RANDOMCHAT CONFIGURATION');
      print('═' * 70);
      print('🌍 Environment:  ${current.name}');
      print('📡 API Base:     ${current.apiUrl}');
      print('🔌 WebSocket:    ${current.wsUrl}');
      print('═' * 70);
    }
  }
}
