import 'package:get/get.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/api_client.dart';
import '../../../../core/services/network/live_socket_client.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/usecases/live_usecases.dart';

/// Owns "who is signed in" and the wallet balance for that person.
///
/// It is registered permanently rather than per route, because the socket
/// connection and the coin balance outlive any single screen.
class SessionController extends GetxController {
  SessionController({
    required this.loginUser,
    required this.registerUser,
    required this.getCurrentUser,
    required this.logoutUser,
    required this.getWallet,
    required this.listCoinPackages,
    required this.topUpWallet,
    required this.socketClient,
    required this.apiClient,
  });

  final LoginUseCase loginUser;
  final RegisterUseCase registerUser;
  final GetCurrentUserUseCase getCurrentUser;
  final LogoutUseCase logoutUser;
  final GetWalletUseCase getWallet;
  final ListCoinPackagesUseCase listCoinPackages;
  final TopUpWalletUseCase topUpWallet;
  final LiveSocketClient socketClient;
  final ApiClient apiClient;

  final Rxn<UserProfileEntity> user = Rxn<UserProfileEntity>();
  final Rx<WalletEntity> wallet = const WalletEntity.empty().obs;
  final RxBool isBusy = false.obs;
  final RxBool isRestoring = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<CoinPackageEntity> coinPackages = <CoinPackageEntity>[].obs;

  bool get isSignedIn => user.value != null;

  @override
  void onInit() {
    super.onInit();
    // A 401 that survives a refresh means the stored session is unusable, so
    // the app drops back to sign-in rather than looping on failed requests.
    apiClient.onSessionExpired = () {
      debugLog('Session expired, signing out');
      _clearSession();
    };
    _restoreSession();
  }

  /// Re-establishes the session from the stored token on cold start, so a
  /// returning user does not see the login screen.
  Future<void> _restoreSession() async {
    try {
      final UserProfileEntity? restored = await getCurrentUser();
      if (restored != null) {
        user.value = restored;
        await Future.wait(<Future<void>>[refreshWallet(), socketClient.connect()]);
      }
    } on AppFailure catch (failure) {
      debugLog('Session restore failed: ${failure.message}');
    } finally {
      isRestoring.value = false;
    }
  }

  Future<bool> login({required String identifier, required String password}) =>
      _authenticate(() => loginUser(identifier: identifier, password: password));

  Future<bool> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) => _authenticate(
    () => registerUser(
      username: username,
      displayName: displayName,
      email: email,
      password: password,
    ),
  );

  Future<bool> _authenticate(Future<AuthSessionEntity> Function() action) async {
    isBusy.value = true;
    errorMessage.value = null;
    try {
      final AuthSessionEntity session = await action();
      user.value = session.user;
      // The socket authenticates with the access token, so it can only be
      // opened once the token has been stored.
      await Future.wait(<Future<void>>[refreshWallet(), socketClient.connect()]);
      return true;
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> refreshWallet() async {
    if (!isSignedIn) {
      return;
    }
    try {
      wallet.value = await getWallet();
    } on AppFailure catch (failure) {
      debugLog('Wallet refresh failed: ${failure.message}');
    }
  }

  /// Applies a balance pushed over the socket after the user sent a gift,
  /// avoiding a round trip just to show the new number.
  void applyWalletUpdate(WalletEntity updated) => wallet.value = updated;

  Future<void> loadCoinPackages() async {
    if (coinPackages.isNotEmpty) {
      return;
    }
    try {
      coinPackages.assignAll(await listCoinPackages());
    } on AppFailure catch (failure) {
      debugLog('Coin packages failed: ${failure.message}');
    }
  }

  Future<bool> purchase(String packageId) async {
    isBusy.value = true;
    errorMessage.value = null;
    try {
      wallet.value = await topUpWallet(packageId);
      return true;
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> logout() async {
    await logoutUser();
    await socketClient.disconnect();
    _clearSession();
  }

  void _clearSession() {
    user.value = null;
    wallet.value = const WalletEntity.empty();
    coinPackages.clear();
  }

  @override
  void onClose() {
    socketClient.dispose();
    super.onClose();
  }
}
