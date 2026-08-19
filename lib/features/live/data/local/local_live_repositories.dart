import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_repositories.dart';
import 'demo_live_backend.dart';

/// Repository implementations backed by [DemoLiveBackend] instead of the API.
///
/// They satisfy the same contracts as the REST implementations, which is the
/// whole point of the interfaces: swapping these in inside the binding turns
/// the app fully offline without a controller, use case or widget changing.
///
/// Each call is delayed a little on purpose. Returning synchronously would
/// make loading states flash by untested, and the demo would behave unlike the
/// networked build it stands in for.
Future<T> _served<T>(T Function() action, {int millis = 180}) =>
    Future<T>.delayed(Duration(milliseconds: millis), action);

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._backend);

  final DemoLiveBackend _backend;

  /// Any credentials are accepted: the local build has no account store, and
  /// the sign-in screen is a demonstration rather than a gate.
  @override
  Future<AuthSessionEntity> login({
    required String identifier,
    required String password,
  }) => _served(() => _backend.signIn(identifier: identifier));

  @override
  Future<AuthSessionEntity> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) => _served(
    () => _backend.signIn(identifier: username, displayName: displayName),
  );

  @override
  Future<UserProfileEntity?> currentUser() async => _backend.currentUser();

  @override
  Future<void> logout() async => _backend.signOut();
}

class LocalLiveStreamRepository implements LiveStreamRepository {
  LocalLiveStreamRepository(this._backend);

  final DemoLiveBackend _backend;

  @override
  Future<PagedResult<LiveStreamEntity>> listLive({
    int page = 1,
    int pageSize = 20,
  }) => _served(() => _backend.listStreams(page: page, pageSize: pageSize));

  @override
  Future<LiveStreamEntity> getById(String streamId) =>
      _served(() => _backend.streamById(streamId));

  @override
  Future<LiveRoomSessionEntity> startBroadcast({
    required String title,
    String? coverUrl,
  }) => _served(
    () => _backend.startBroadcast(title: title, coverUrl: coverUrl),
    millis: 320,
  );

  @override
  Future<LiveRoomSessionEntity> join(String streamId) =>
      _served(() => _backend.join(streamId), millis: 260);

  @override
  Future<void> end(String streamId) async => _backend.end(streamId);

  @override
  Future<void> heartbeat(String streamId) async => _backend.heartbeat(streamId);

  @override
  Future<int> sendReaction(String streamId, int count) async =>
      _backend.react(streamId, count);
}

class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this._backend);

  final DemoLiveBackend _backend;

  @override
  Future<List<ChatMessageEntity>> history(String streamId, {int? limit}) =>
      _served(() => _backend.chatHistory(streamId, limit: limit));

  @override
  Future<ChatMessageEntity> send(String streamId, String body) async =>
      _backend.sendChat(streamId, body);
}

class LocalGiftRepository implements GiftRepository {
  LocalGiftRepository(this._backend);

  final DemoLiveBackend _backend;

  @override
  Future<List<GiftEntity>> catalogue() => _served(() => _backend.gifts);

  /// Sending is not delayed: the animation should start on the tap, not a
  /// fifth of a second after it.
  @override
  Future<({GiftEventEntity event, WalletEntity wallet})> send({
    required String streamId,
    required String giftCode,
    required int quantity,
  }) async => _backend.sendGift(
    streamId: streamId,
    giftCode: giftCode,
    quantity: quantity,
  );

  @override
  Future<List<LeaderboardEntryEntity>> streamLeaderboard(
    String streamId, {
    int? limit,
  }) => _served(() => _backend.streamLeaderboard(streamId, limit: limit));

  @override
  Future<List<LeaderboardEntryEntity>> globalLeaderboard({
    String board = 'hosts',
    String window = 'weekly',
    int? limit,
  }) => _served(
    () =>
        _backend.globalLeaderboard(board: board, window: window, limit: limit),
  );
}

class LocalWalletRepository implements WalletRepository {
  LocalWalletRepository(this._backend);

  final DemoLiveBackend _backend;

  @override
  Future<WalletEntity> balance() async => _backend.wallet;

  @override
  Future<List<CoinPackageEntity>> packages() =>
      _served(() => _backend.coinPackages);

  @override
  Future<WalletEntity> topUp(String packageId) =>
      _served(() => _backend.topUp(packageId), millis: 400);
}
