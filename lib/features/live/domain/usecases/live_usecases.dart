import '../entities/live_entities.dart';
import '../repositories/live_repositories.dart';

/// One class per action, each a single `call`. This mirrors the camera
/// feature's use case style and keeps controllers free of repository plumbing.

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthSessionEntity> call({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) => _repository.register(
    username: username,
    displayName: displayName,
    email: email,
    password: password,
  );
}

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthSessionEntity> call({
    required String identifier,
    required String password,
  }) => _repository.login(identifier: identifier, password: password);
}

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;
  Future<UserProfileEntity?> call() => _repository.currentUser();
}

class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;
  Future<void> call() => _repository.logout();
}

// ---------------------------------------------------------------------------
// Streams
// ---------------------------------------------------------------------------

class ListLiveStreamsUseCase {
  const ListLiveStreamsUseCase(this._repository);
  final LiveStreamRepository _repository;

  Future<PagedResult<LiveStreamEntity>> call({
    int page = 1,
    int pageSize = 20,
  }) => _repository.listLive(page: page, pageSize: pageSize);
}

class StartBroadcastUseCase {
  const StartBroadcastUseCase(this._repository);
  final LiveStreamRepository _repository;

  Future<LiveRoomSessionEntity> call({
    required String title,
    String? coverUrl,
  }) => _repository.startBroadcast(title: title, coverUrl: coverUrl);
}

class JoinStreamUseCase {
  const JoinStreamUseCase(this._repository);
  final LiveStreamRepository _repository;
  Future<LiveRoomSessionEntity> call(String streamId) =>
      _repository.join(streamId);
}

class EndStreamUseCase {
  const EndStreamUseCase(this._repository);
  final LiveStreamRepository _repository;
  Future<void> call(String streamId) => _repository.end(streamId);
}

class HeartbeatUseCase {
  const HeartbeatUseCase(this._repository);
  final LiveStreamRepository _repository;
  Future<void> call(String streamId) => _repository.heartbeat(streamId);
}

class SendReactionUseCase {
  const SendReactionUseCase(this._repository);
  final LiveStreamRepository _repository;
  Future<int> call(String streamId, int count) =>
      _repository.sendReaction(streamId, count);
}

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

class SendChatMessageUseCase {
  const SendChatMessageUseCase(this._repository);
  final ChatRepository _repository;
  Future<ChatMessageEntity> call(String streamId, String body) =>
      _repository.send(streamId, body);
}

class LoadChatHistoryUseCase {
  const LoadChatHistoryUseCase(this._repository);
  final ChatRepository _repository;
  Future<List<ChatMessageEntity>> call(String streamId, {int? limit}) =>
      _repository.history(streamId, limit: limit);
}

// ---------------------------------------------------------------------------
// Gifts
// ---------------------------------------------------------------------------

class LoadGiftCatalogueUseCase {
  const LoadGiftCatalogueUseCase(this._repository);
  final GiftRepository _repository;
  Future<List<GiftEntity>> call() => _repository.catalogue();
}

class SendGiftUseCase {
  const SendGiftUseCase(this._repository);
  final GiftRepository _repository;

  Future<({GiftEventEntity event, WalletEntity wallet})> call({
    required String streamId,
    required String giftCode,
    int quantity = 1,
  }) => _repository.send(
    streamId: streamId,
    giftCode: giftCode,
    quantity: quantity,
  );
}

class StreamLeaderboardUseCase {
  const StreamLeaderboardUseCase(this._repository);
  final GiftRepository _repository;
  Future<List<LeaderboardEntryEntity>> call(String streamId, {int? limit}) =>
      _repository.streamLeaderboard(streamId, limit: limit);
}

class GlobalLeaderboardUseCase {
  const GlobalLeaderboardUseCase(this._repository);
  final GiftRepository _repository;

  Future<List<LeaderboardEntryEntity>> call({
    String board = 'hosts',
    String window = 'weekly',
    int? limit,
  }) =>
      _repository.globalLeaderboard(board: board, window: window, limit: limit);
}

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

class GetWalletUseCase {
  const GetWalletUseCase(this._repository);
  final WalletRepository _repository;
  Future<WalletEntity> call() => _repository.balance();
}

class ListCoinPackagesUseCase {
  const ListCoinPackagesUseCase(this._repository);
  final WalletRepository _repository;
  Future<List<CoinPackageEntity>> call() => _repository.packages();
}

class TopUpWalletUseCase {
  const TopUpWalletUseCase(this._repository);
  final WalletRepository _repository;
  Future<WalletEntity> call(String packageId) => _repository.topUp(packageId);
}
