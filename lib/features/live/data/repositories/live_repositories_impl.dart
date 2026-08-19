import '../../../../core/services/storage/token_storage.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_repositories.dart';
import '../datasources/live_remote_data_source.dart';
import '../models/live_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokenStorage);

  final LiveRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSessionEntity> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) => _persist(
    _remote.register(<String, dynamic>{
      'username': username,
      'displayName': displayName,
      'email': email,
      'password': password,
    }),
  );

  @override
  Future<AuthSessionEntity> login({
    required String identifier,
    required String password,
  }) => _persist(
    _remote.login(<String, dynamic>{
      'identifier': identifier,
      'password': password,
    }),
  );

  /// Tokens are written before the session is handed back, so the caller can
  /// immediately make an authenticated request or open the socket.
  Future<AuthSessionEntity> _persist(
    Future<Map<String, dynamic>> request,
  ) async {
    final Map<String, dynamic> data = await request;
    final Map<String, dynamic> tokens = LiveModelParsers.asMap(data['tokens']);
    final String accessToken = LiveModelParsers.asString(tokens['accessToken']);
    final String refreshToken = LiveModelParsers.asString(
      tokens['refreshToken'],
    );

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return AuthSessionEntity(
      user: UserProfileModel.fromJson(LiveModelParsers.asMap(data['user'])),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<UserProfileEntity?> currentUser() async {
    if (await _tokenStorage.readAccessToken() == null) {
      return null;
    }
    final Map<String, dynamic> data = await _remote.me();
    return UserProfileModel.fromJson(LiveModelParsers.asMap(data['user']));
  }

  @override
  Future<void> logout() => _tokenStorage.clear();
}

class LiveStreamRepositoryImpl implements LiveStreamRepository {
  const LiveStreamRepositoryImpl(this._remote);

  final LiveRemoteDataSource _remote;

  @override
  Future<PagedResult<LiveStreamEntity>> listLive({
    int page = 1,
    int pageSize = 20,
  }) async {
    final Map<String, dynamic> data = await _remote.listStreams(
      page: page,
      pageSize: pageSize,
    );
    return PagedResult<LiveStreamEntity>(
      items: LiveModelParsers.asMapList(
        data['items'],
      ).map(LiveStreamModel.fromJson).toList(growable: false),
      page: LiveModelParsers.asInt(data['page'], 1),
      total: LiveModelParsers.asInt(data['total']),
      hasMore: data['hasMore'] == true,
    );
  }

  @override
  Future<LiveStreamEntity> getById(String streamId) async {
    final Map<String, dynamic> data = await _remote.getStream(streamId);
    return LiveStreamModel.fromJson(LiveModelParsers.asMap(data['stream']));
  }

  @override
  Future<LiveRoomSessionEntity> startBroadcast({
    required String title,
    String? coverUrl,
  }) async {
    final Map<String, dynamic> data = await _remote.startStream(
      <String, dynamic>{'title': title, 'coverUrl': ?coverUrl},
    );
    return LiveRoomSessionModel.fromJson(data);
  }

  @override
  Future<LiveRoomSessionEntity> join(String streamId) async {
    final Map<String, dynamic> data = await _remote.joinStream(streamId);
    return LiveRoomSessionModel.fromJson(data);
  }

  @override
  Future<void> end(String streamId) => _remote.endStream(streamId);

  @override
  Future<void> heartbeat(String streamId) => _remote.heartbeat(streamId);

  @override
  Future<int> sendReaction(String streamId, int count) async {
    final Map<String, dynamic> data = await _remote.sendReaction(
      streamId,
      count,
    );
    return LiveModelParsers.asInt(data['totalLikes']);
  }
}

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._remote);

  final LiveRemoteDataSource _remote;

  @override
  Future<List<ChatMessageEntity>> history(String streamId, {int? limit}) async {
    final Map<String, dynamic> data = await _remote.chatHistory(
      streamId,
      limit: limit,
    );
    return LiveModelParsers.asMapList(
      data['items'],
    ).map(ChatMessageModel.fromJson).toList(growable: false);
  }

  @override
  Future<ChatMessageEntity> send(String streamId, String body) async {
    final Map<String, dynamic> data = await _remote.sendChat(streamId, body);
    return ChatMessageModel.fromJson(LiveModelParsers.asMap(data['message']));
  }
}

class GiftRepositoryImpl implements GiftRepository {
  const GiftRepositoryImpl(this._remote);

  final LiveRemoteDataSource _remote;

  @override
  Future<List<GiftEntity>> catalogue() async {
    final Map<String, dynamic> data = await _remote.gifts();
    return LiveModelParsers.asMapList(
      data['items'],
    ).map(GiftModel.fromJson).toList(growable: false);
  }

  @override
  Future<({GiftEventEntity event, WalletEntity wallet})> send({
    required String streamId,
    required String giftCode,
    required int quantity,
  }) async {
    final Map<String, dynamic> data = await _remote.sendGift(
      streamId,
      giftCode,
      quantity,
      'gift-${DateTime.now().microsecondsSinceEpoch}-$giftCode-$quantity',
    );
    return (
      event: GiftEventModel.fromJson(LiveModelParsers.asMap(data['giftEvent'])),
      wallet: WalletModel.fromJson(LiveModelParsers.asMap(data['wallet'])),
    );
  }

  @override
  Future<List<LeaderboardEntryEntity>> streamLeaderboard(
    String streamId, {
    int? limit,
  }) async {
    final Map<String, dynamic> data = await _remote.streamLeaderboard(
      streamId,
      limit: limit,
    );
    return LeaderboardEntryModel.listFrom(data['items']);
  }

  @override
  Future<List<LeaderboardEntryEntity>> globalLeaderboard({
    String board = 'hosts',
    String window = 'weekly',
    int? limit,
  }) async {
    final Map<String, dynamic> data = await _remote.globalLeaderboard(
      board: board,
      window: window,
      limit: limit,
    );
    return LeaderboardEntryModel.listFrom(data['items']);
  }
}

class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl(this._remote);

  final LiveRemoteDataSource _remote;

  @override
  Future<WalletEntity> balance() async {
    final Map<String, dynamic> data = await _remote.wallet();
    return WalletModel.fromJson(LiveModelParsers.asMap(data['wallet']));
  }

  @override
  Future<List<CoinPackageEntity>> packages() async {
    final Map<String, dynamic> data = await _remote.coinPackages();
    return LiveModelParsers.asMapList(
      data['items'],
    ).map(CoinPackageModel.fromJson).toList(growable: false);
  }

  @override
  Future<WalletEntity> topUp(String packageId) async {
    final Map<String, dynamic> data = await _remote.topUp(packageId);
    return WalletModel.fromJson(LiveModelParsers.asMap(data['wallet']));
  }
}
