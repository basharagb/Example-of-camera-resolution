import '../entities/live_entities.dart';

/// Repository contracts. The presentation layer depends on these interfaces
/// only, which is what allows the REST + Socket.IO implementation to be
/// swapped without touching a controller.

abstract interface class AuthRepository {
  Future<AuthSessionEntity> register({
    required String username,
    required String displayName,
    required String email,
    required String password,
  });

  Future<AuthSessionEntity> login({
    required String identifier,
    required String password,
  });

  /// The stored session, or null when nobody is signed in.
  Future<UserProfileEntity?> currentUser();

  Future<void> logout();
}

abstract interface class LiveStreamRepository {
  Future<PagedResult<LiveStreamEntity>> listLive({int page, int pageSize});

  Future<LiveStreamEntity> getById(String streamId);

  /// Opens a room and returns the host's publishing credentials.
  Future<LiveRoomSessionEntity> startBroadcast({
    required String title,
    String? coverUrl,
  });

  /// Returns the viewer's subscribe credentials plus the warm room state.
  Future<LiveRoomSessionEntity> join(String streamId);

  Future<void> end(String streamId);

  Future<void> heartbeat(String streamId);

  Future<int> sendReaction(String streamId, int count);
}

abstract interface class ChatRepository {
  Future<List<ChatMessageEntity>> history(String streamId, {int? limit});

  Future<ChatMessageEntity> send(String streamId, String body);
}

abstract interface class GiftRepository {
  Future<List<GiftEntity>> catalogue();

  /// Sends a gift and returns the sender's wallet after the debit.
  Future<({GiftEventEntity event, WalletEntity wallet})> send({
    required String streamId,
    required String giftCode,
    required int quantity,
  });

  Future<List<LeaderboardEntryEntity>> streamLeaderboard(String streamId, {int? limit});

  Future<List<LeaderboardEntryEntity>> globalLeaderboard({
    String board,
    String window,
    int? limit,
  });
}

abstract interface class WalletRepository {
  Future<WalletEntity> balance();

  Future<List<CoinPackageEntity>> packages();

  Future<WalletEntity> topUp(String packageId);
}
