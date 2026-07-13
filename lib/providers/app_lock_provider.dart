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
    if (!_isEnabled || _isLocked) return;
    // On verrouille dès `inactive` (perte de focus) et pas seulement
    // `paused` (arrière-plan) : `inactive` est l'état capturé par l'OS pour
    // l'aperçu du multitâche/l'animation de retour. Si on attendait
    // `paused`, ce cliché contiendrait encore le contenu de l'app, ce qui
    // provoque un flash visible avant l'affichage de l'écran de
    // verrouillage au retour dans l'app.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _isLocked = true;
      notifyListeners();
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
    if (!_canUseBiometrics) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Déverrouille KashFlo',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated) unlock();
      return authenticated;
    } catch (_) {
      return false;
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
