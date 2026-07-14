import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _kLockEnabledKey = 'app_lock_enabled';
const _kLockPinKey = 'app_lock_pin';

/// Gère le verrouillage de l'application par code PIN et/ou biométrie.
///
/// Le code est stocké tel quel dans le stockage sécurisé du système
/// (Keychain iOS / Keystore Android), ce qui est suffisant pour un
/// verrouillage d'écran local (pas un système d'authentification serveur).
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _isLoading = true;
  bool _isEnabled = false;
  bool _isLocked = false;
  bool _canUseBiometrics = false;
  bool _isAuthenticating = false;
  bool _showPrivacyCover = false;

  bool get isLoading => _isLoading;
  bool get isEnabled => _isEnabled;
  bool get isLocked => _isLocked;
  bool get canUseBiometrics => _canUseBiometrics;

  /// Cache visuellement le contenu (sans exiger de déverrouillage) dès que
  /// l'app perd le focus (`inactive`), pour éviter que l'instantané pris par
  /// l'OS pour l'aperçu du multitâche/l'animation de retour ne contienne des
  /// données sensibles. Contrairement à [isLocked], ce cache n'implique pas
  /// forcément une demande de code : il disparaît immédiatement si l'app
  /// revient au premier plan sans être vraiment passée en arrière-plan
  /// (centre de contrôle, volet de notification…).
  bool get showPrivacyCover => _showPrivacyCover;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    final enabled = await _storage.read(key: _kLockEnabledKey);
    _isEnabled = enabled == 'true';
    _isLocked = _isEnabled;

    try {
      _canUseBiometrics =
          await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (_) {
      _canUseBiometrics = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEnabled) return;

    switch (state) {
      // L'OS prend son instantané (aperçu du multitâche / animation de
      // retour) au moment de `inactive`, pas plus tard. On cache donc le
      // contenu dès cet instant — mais sans verrouiller : `inactive` se
      // déclenche aussi pour le centre de contrôle, le volet de
      // notification, un appel entrant, etc., où l'app reste au premier
      // plan et où exiger le code serait intempestif.
      case AppLifecycleState.inactive:
        _showPrivacyCover = true;
        notifyListeners();

      // `hidden` n'est synthétisé par Flutter que juste avant `paused`,
      // quand l'app quitte vraiment l'écran (changement d'app, bouton
      // home) : c'est le bon signal pour exiger un déverrouillage.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_isLocked) {
          _isLocked = true;
          notifyListeners();
        }

      case AppLifecycleState.resumed:
        _showPrivacyCover = false;
        // Tente la biométrie directement depuis le provider plutôt que de
        // compter sur le rebuild de l'écran de verrouillage
        // (postFrameCallback) : ce dernier n'est pas fiable juste après un
        // retour d'arrière-plan (aucune frame garantie immédiatement).
        if (_isLocked) {
          unlockWithBiometrics();
        } else {
          notifyListeners();
        }

      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> setupPin(String pin) async {
    await _storage.write(key: _kLockPinKey, value: pin);
    await _storage.write(key: _kLockEnabledKey, value: 'true');
    _isEnabled = true;
    _isLocked = false;
    notifyListeners();
  }

  Future<bool> changePin(String currentPin, String newPin) async {
    if (!await verifyPin(currentPin)) return false;
    await _storage.write(key: _kLockPinKey, value: newPin);
    return true;
  }

  Future<bool> disable(String pin) async {
    if (!await verifyPin(pin)) return false;
    await _storage.delete(key: _kLockPinKey);
    await _storage.write(key: _kLockEnabledKey, value: 'false');
    _isEnabled = false;
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _kLockPinKey);
    return stored != null && stored == pin;
  }

  Future<bool> unlockWithBiometrics() async {
    // Évite un double prompt si l'écran de verrouillage et le retour au
    // premier plan déclenchent tous les deux une tentative simultanément.
    if (!_canUseBiometrics || _isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Déverrouille KashFlo',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated) unlock();
      return authenticated;
    } catch (_) {
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
