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

  bool get isLoading => _isLoading;
  bool get isEnabled => _isEnabled;
  bool get isLocked => _isLocked;
  bool get canUseBiometrics => _canUseBiometrics;

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

    // `inactive` se déclenche aussi pour le centre de contrôle, le volet de
    // notification, un appel entrant, etc. (l'app reste visible, juste sans
    // focus) — verrouiller à ce moment-là est trop agressif.
    // `hidden` n'est synthétisé par Flutter que juste avant `paused`, quand
    // l'app quitte vraiment l'écran (changement d'app, bouton home) : c'est
    // le bon signal, et il arrive assez tôt pour éviter le flash de contenu
    // qu'on aurait avec `paused` seul (l'OS capture son instantané du
    // multitâche à ce moment précis).
    if (!_isLocked &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused)) {
      _isLocked = true;
      notifyListeners();
      return;
    }

    // Au retour au premier plan alors que l'app est verrouillée, on tente
    // la biométrie directement depuis le provider plutôt que de compter sur
    // le rebuild de l'écran de verrouillage (postFrameCallback) : ce dernier
    // n'est pas fiable juste après un retour d'arrière-plan (aucune frame
    // garantie immédiatement).
    if (_isLocked && state == AppLifecycleState.resumed) {
      unlockWithBiometrics();
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
