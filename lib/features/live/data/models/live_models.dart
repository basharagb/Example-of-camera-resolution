import '../../domain/entities/live_entities.dart';

/// JSON boundary. Every field the server can send is parsed here and nowhere
/// else, so a payload change is a one file edit.
///
/// Parsing is deliberately forgiving about numeric types: MySQL BIGINT columns
/// arrive as strings once they grow past the safe integer range, and JSON
/// numbers arrive as int or double depending on the value.
abstract final class LiveModelParsers {
  static int asInt(Object? value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double asDouble(Object? value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static String asString(Object? value, [String fallback = '']) =>
      value?.toString() ?? fallback;

  /// The server sends ISO-8601 UTC. A malformed or missing value falls back to
  /// "now" rather than throwing, because one bad timestamp should not take out
  /// a whole chat list.
  static DateTime asDate(Object? value) {
    if (value is DateTime) return value;
    final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
    return (parsed ?? DateTime.now()).toLocal();
  }

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asMapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }
}

extension UserProfileModel on UserProfileEntity {
  static UserProfileEntity fromJson(Map<String, dynamic> json) {
    final String username = LiveModelParsers.asString(
      json['username'],
      'guest',
    );
    return UserProfileEntity(
      id: LiveModelParsers.asString(json['id']),
      username: username,
      // A user the server only referenced by id still needs a label.
      displayName: LiveModelParsers.asString(json['displayName'], username),
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
    );
  }
}

extension WalletModel on WalletEntity {
  static WalletEntity fromJson(Map<String, dynamic> json) => WalletEntity(
    coinBalance: LiveModelParsers.asInt(json['coinBalance']),
    diamondBalance: LiveModelParsers.asInt(json['diamondBalance']),
    lifetimeCoinsSpent: LiveModelParsers.asInt(json['lifetimeCoinsSpent']),
    lifetimeDiamondsEarned: LiveModelParsers.asInt(
      json['lifetimeDiamondsEarned'],
    ),
  );
}

extension LiveStreamModel on LiveStreamEntity {
  static LiveStreamEntity fromJson(Map<String, dynamic> json) =>
      LiveStreamEntity(
        id: LiveModelParsers.asString(json['id']),
        title: LiveModelParsers.asString(json['title']),
        status: LiveModelParsers.asString(json['status']) == 'ended'
            ? LiveStreamStatus.ended
            : LiveStreamStatus.live,
        viewerCount: LiveModelParsers.asInt(json['viewerCount']),
        totalLikes: LiveModelParsers.asInt(json['totalLikes']),
        totalCoins: LiveModelParsers.asInt(json['totalCoins']),
        startedAt: LiveModelParsers.asDate(json['startedAt']),
        host: UserProfileModel.fromJson(LiveModelParsers.asMap(json['host'])),
        coverUrl: json['coverUrl'] as String?,
        channelName: json['channelName'] as String?,
        peakViewerCount: LiveModelParsers.asInt(json['peakViewerCount']),
        totalGifts: LiveModelParsers.asInt(json['totalGifts']),
        durationSeconds: LiveModelParsers.asInt(json['durationSeconds']),
        endedAt: json['endedAt'] == null
            ? null
            : LiveModelParsers.asDate(json['endedAt']),
      );
}

extension RtcCredentialsModel on RtcCredentialsEntity {
  static RtcCredentialsEntity fromJson(Map<String, dynamic> json) =>
      RtcCredentialsEntity(
        provider: LiveModelParsers.asString(json['provider'], 'mock'),
        serverUrl: LiveModelParsers.asString(json['serverUrl']),
        localServerUrl: LiveModelParsers.asString(
          json['localServerUrl'],
          LiveModelParsers.asString(json['serverUrl']),
        ),
        channelName: LiveModelParsers.asString(json['channelName']),
        uid: LiveModelParsers.asInt(json['uid']),
        token: LiveModelParsers.asString(json['token']),
        role: LiveModelParsers.asString(json['role'], 'audience'),
        expiresAt: LiveModelParsers.asDate(json['expiresAt']),
      );
}

extension GiftModel on GiftEntity {
  static GiftEntity fromJson(Map<String, dynamic> json) {
    final String tier = LiveModelParsers.asString(json['tier'], 'basic');
    return GiftEntity(
      id: LiveModelParsers.asString(json['id']),
      code: LiveModelParsers.asString(json['code']),
      name: LiveModelParsers.asString(json['name']),
      nameAr: LiveModelParsers.asString(
        json['nameAr'],
        LiveModelParsers.asString(json['name']),
      ),
      coinCost: LiveModelParsers.asInt(json['coinCost']),
      tier: GiftTier.values.firstWhere(
        (GiftTier value) => value.name == tier,
        orElse: () => GiftTier.basic,
      ),
      animationDurationMs: LiveModelParsers.asInt(
        json['animationDurationMs'],
        2000,
      ),
      animationType: LiveModelParsers.asString(json['animationType'], 'float'),
      iconUrl: json['iconUrl'] as String?,
      animationAsset: json['animationAsset'] as String?,
    );
  }
}

extension GiftEventModel on GiftEventEntity {
  static GiftEventEntity fromJson(Map<String, dynamic> json) => GiftEventEntity(
    id: LiveModelParsers.asString(json['id']),
    streamId: LiveModelParsers.asString(json['streamId']),
    quantity: LiveModelParsers.asInt(json['quantity'], 1),
    coinCost: LiveModelParsers.asInt(json['coinCost']),
    createdAt: LiveModelParsers.asDate(json['createdAt']),
    gift: GiftModel.fromJson(LiveModelParsers.asMap(json['gift'])),
    sender: UserProfileModel.fromJson(LiveModelParsers.asMap(json['sender'])),
    comboKey: json['comboKey'] as String?,
    // Present on the realtime broadcast; absent on a plain REST reply, where
    // the gift's own duration is the right default.
    animationDurationMs: LiveModelParsers.asInt(
      json['animationDurationMs'],
      LiveModelParsers.asInt(
        LiveModelParsers.asMap(json['gift'])['animationDurationMs'],
        2000,
      ),
    ),
  );
}

extension ChatMessageModel on ChatMessageEntity {
  static ChatMessageEntity fromJson(Map<String, dynamic> json) {
    final String kind = LiveModelParsers.asString(json['kind'], 'text');
    return ChatMessageEntity(
      id: LiveModelParsers.asString(json['id']),
      streamId: LiveModelParsers.asString(json['streamId']),
      body: json['body'] as String?,
      kind: ChatMessageKind.values.firstWhere(
        (ChatMessageKind value) => value.name == kind,
        orElse: () => ChatMessageKind.text,
      ),
      createdAt: LiveModelParsers.asDate(json['createdAt']),
      sender: UserProfileModel.fromJson(LiveModelParsers.asMap(json['sender'])),
    );
  }
}

extension LeaderboardEntryModel on LeaderboardEntryEntity {
  static LeaderboardEntryEntity fromJson(
    Map<String, dynamic> json,
    int fallbackRank,
  ) => LeaderboardEntryEntity(
    rank: LiveModelParsers.asInt(json['rank'], fallbackRank),
    user: UserProfileModel.fromJson(LiveModelParsers.asMap(json['user'])),
    totalCoins: LiveModelParsers.asInt(json['totalCoins']),
    totalDiamonds: LiveModelParsers.asInt(json['totalDiamonds']),
    giftCount: LiveModelParsers.asInt(json['giftCount']),
  );

  static List<LeaderboardEntryEntity> listFrom(Object? value) {
    final List<Map<String, dynamic>> raw = LiveModelParsers.asMapList(value);
    return <LeaderboardEntryEntity>[
      for (int index = 0; index < raw.length; index++)
        LeaderboardEntryModel.fromJson(raw[index], index + 1),
    ];
  }
}

extension CoinPackageModel on CoinPackageEntity {
  static CoinPackageEntity fromJson(Map<String, dynamic> json) =>
      CoinPackageEntity(
        id: LiveModelParsers.asString(json['id']),
        label: LiveModelParsers.asString(json['label']),
        coins: LiveModelParsers.asInt(json['coins']),
        priceUsd: LiveModelParsers.asDouble(json['priceUsd']),
      );
}

extension LiveRoomSessionModel on LiveRoomSessionEntity {
  static LiveRoomSessionEntity fromJson(Map<String, dynamic> json) =>
      LiveRoomSessionEntity(
        stream: LiveStreamModel.fromJson(
          LiveModelParsers.asMap(json['stream']),
        ),
        rtc: RtcCredentialsModel.fromJson(LiveModelParsers.asMap(json['rtc'])),
        // The start-broadcast reply has no `role` field: opening a room always
        // makes you its host.
        role: LiveModelParsers.asString(json['role'], 'host'),
        recentMessages: LiveModelParsers.asMapList(
          json['recentMessages'],
        ).map(ChatMessageModel.fromJson).toList(growable: false),
        topGifters: LeaderboardEntryModel.listFrom(json['topGifters']),
      );
}
