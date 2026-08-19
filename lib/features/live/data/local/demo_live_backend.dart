import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/live_events_client.dart';
import '../../domain/entities/live_entities.dart';
import 'demo_catalogue.dart';

/// The whole live product, running inside the app.
///
/// This is the server: rooms, chat, wallet, gifts, leaderboards and the
/// realtime feed, all in memory. Nothing here opens a socket or a request, so
/// the demo works on a plane, on a phone with no SIM, and with the backend
/// switched off. State lives for the life of the process and resets on a cold
/// start, which is what a demo wants - every run starts from the same place.
///
/// It deliberately reproduces the API's *behaviour*, not just its data: a gift
/// debits the wallet, credits the host, moves the leaderboard, and is
/// announced on the realtime feed exactly like the server announces it. The
/// controllers therefore run their real code paths rather than a shortcut.
class DemoLiveBackend {
  DemoLiveBackend._() {
    _seedRooms();
  }

  static final DemoLiveBackend instance = DemoLiveBackend._();

  /// A backend of its own, so a test starts from the seeded state instead of
  /// whatever the previous test left in the singleton.
  @visibleForTesting
  factory DemoLiveBackend.forTest() = DemoLiveBackend._;

  final Random _random = Random();
  final StreamController<LiveRealtimeEvent> _events =
      StreamController<LiveRealtimeEvent>.broadcast();

  final Map<String, _DemoRoom> _rooms = <String, _DemoRoom>{};

  UserProfileEntity? _signedIn = DemoCatalogue.localUser;

  /// Enough to reach every tier, including the 29,999 coin legendary, without
  /// a top up. Topping up still works and is instant.
  WalletEntity _wallet = const WalletEntity(
    coinBalance: 250000,
    diamondBalance: 0,
    lifetimeCoinsSpent: 0,
    lifetimeDiamondsEarned: 0,
  );

  int _sequence = 0;

  Stream<LiveRealtimeEvent> get events => _events.stream;

  UserProfileEntity get me => _signedIn ?? DemoCatalogue.localUser;
  WalletEntity get wallet => _wallet;
  List<GiftEntity> get gifts =>
      List<GiftEntity>.unmodifiable(DemoCatalogue.gifts);
  List<CoinPackageEntity> get coinPackages => DemoCatalogue.coinPackages;

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  // ---------------------------------------------------------------------------
  // Auth. There is no password check anywhere: the local build is signed in
  // from the first frame, and the sign-in screen is kept only so the flow can
  // still be demonstrated.
  // ---------------------------------------------------------------------------

  AuthSessionEntity signIn({String? identifier, String? displayName}) {
    final String username = (identifier ?? '').trim().isEmpty
        ? DemoCatalogue.localUser.username
        : identifier!.trim().split('@').first;
    _signedIn = UserProfileEntity(
      id: DemoCatalogue.localUser.id,
      username: username,
      displayName: (displayName ?? '').trim().isEmpty
          ? (username == DemoCatalogue.localUser.username
                ? DemoCatalogue.localUser.displayName
                : username)
          : displayName!.trim(),
      bio: DemoCatalogue.localUser.bio,
    );
    return AuthSessionEntity(
      user: _signedIn!,
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
    );
  }

  UserProfileEntity? currentUser() => _signedIn;

  void signOut() => _signedIn = null;

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  PagedResult<LiveStreamEntity> listStreams({int page = 1, int pageSize = 20}) {
    final List<LiveStreamEntity> live =
        _rooms.values
            .where((_DemoRoom room) => room.status == LiveStreamStatus.live)
            .map((_DemoRoom room) => room.toEntity())
            .toList()
          // Newest first, matching the server's ordering.
          ..sort(
            (LiveStreamEntity a, LiveStreamEntity b) =>
                b.startedAt.compareTo(a.startedAt),
          );

    final int start = (page - 1) * pageSize;
    if (start >= live.length) {
      return PagedResult<LiveStreamEntity>(
        items: const <LiveStreamEntity>[],
        page: page,
        total: live.length,
        hasMore: false,
      );
    }
    final int end = min(start + pageSize, live.length);
    return PagedResult<LiveStreamEntity>(
      items: live.sublist(start, end),
      page: page,
      total: live.length,
      hasMore: end < live.length,
    );
  }

  LiveStreamEntity streamById(String streamId) => _require(streamId).toEntity();

  // ---------------------------------------------------------------------------
  // Rooms
  // ---------------------------------------------------------------------------

  LiveRoomSessionEntity startBroadcast({
    required String title,
    String? coverUrl,
  }) {
    // One host, one room: reopening replaces the previous broadcast instead of
    // leaving an orphan in the feed, with its crowd timer still running.
    for (final _DemoRoom previous in _rooms.values.toList()) {
      if (previous.isMine) {
        _stopSimulation(previous);
        _rooms.remove(previous.id);
      }
    }

    final String id = _nextId('room');
    final _DemoRoom room = _DemoRoom(
      id: id,
      title: title.trim().isEmpty ? 'Live now' : title.trim(),
      host: me,
      coverUrl: coverUrl,
      channelName: 'demo_$id',
      startedAt: DateTime.now(),
      isMine: true,
    );
    _rooms[id] = room;

    _emit(LiveEvents.streamStarted, <String, dynamic>{
      'stream': _streamJson(room),
    });
    _startSimulation(room);

    return LiveRoomSessionEntity(
      stream: room.toEntity(),
      rtc: _credentials(room, role: 'host'),
      role: 'host',
      recentMessages: List<ChatMessageEntity>.unmodifiable(room.messages),
      topGifters: _leaderboardFor(room, limit: 3),
    );
  }

  LiveRoomSessionEntity join(String streamId) {
    final _DemoRoom room = _require(streamId);
    if (room.status != LiveStreamStatus.live) {
      throw const NotFoundFailure('This live has already ended');
    }
    room.viewerCount += 1;
    room.peakViewerCount = max(room.peakViewerCount, room.viewerCount);
    _startSimulation(room);

    return LiveRoomSessionEntity(
      stream: room.toEntity(),
      rtc: _credentials(room, role: 'audience'),
      role: 'audience',
      recentMessages: List<ChatMessageEntity>.unmodifiable(room.messages),
      topGifters: _leaderboardFor(room, limit: 3),
    );
  }

  void end(String streamId) {
    final _DemoRoom? room = _rooms[streamId];
    if (room == null || room.status == LiveStreamStatus.ended) {
      return;
    }
    room.status = LiveStreamStatus.ended;
    room.endedAt = DateTime.now();
    _stopSimulation(room);
    _emit(LiveEvents.streamEnded, <String, dynamic>{'streamId': room.id});

    // A room the demo user opened disappears for good; the seeded rooms come
    // back on the next launch, so the feed is never permanently emptied.
    if (room.isMine) {
      _rooms.remove(room.id);
    }
  }

  void heartbeat(String streamId) =>
      _rooms[streamId]?.lastHeartbeat = DateTime.now();

  void leave(String streamId) {
    final _DemoRoom? room = _rooms[streamId];
    if (room == null) {
      return;
    }
    room.viewerCount = max(0, room.viewerCount - 1);
    // Seeded rooms keep simulating only while somebody is inside them.
    if (!room.isMine) {
      _stopSimulation(room);
    }
  }

  int react(String streamId, int count) {
    final _DemoRoom room = _require(streamId);
    room.totalLikes += count.clamp(1, 50);
    _emit(LiveEvents.reactionBurst, <String, dynamic>{
      'streamId': room.id,
      'senderId': me.id,
      'count': count,
      'totalLikes': room.totalLikes,
    });
    return room.totalLikes;
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  List<ChatMessageEntity> chatHistory(String streamId, {int? limit}) {
    final _DemoRoom room = _require(streamId);
    final List<ChatMessageEntity> all = room.messages;
    if (limit == null || limit >= all.length) {
      return List<ChatMessageEntity>.unmodifiable(all);
    }
    return List<ChatMessageEntity>.unmodifiable(
      all.sublist(all.length - limit),
    );
  }

  ChatMessageEntity sendChat(String streamId, String body) {
    final _DemoRoom room = _require(streamId);
    final ChatMessageEntity message = ChatMessageEntity(
      id: _nextId('msg'),
      streamId: room.id,
      body: body,
      kind: ChatMessageKind.text,
      createdAt: DateTime.now(),
      sender: me,
    );
    _appendMessage(room, message);
    // Echoed on the realtime feed, exactly like the server does, so the sender
    // sees their own line through the same path as everyone else.
    _emit(LiveEvents.chatMessage, _chatJson(message));
    return message;
  }

  // ---------------------------------------------------------------------------
  // Gifts
  //
  // Sending to your own room is allowed here on purpose: with a single device
  // it is the only way to see the full send -> debit -> animation -> podium
  // path, and the host's own diamonds going up is the receiving half of it.
  // ---------------------------------------------------------------------------

  ({GiftEventEntity event, WalletEntity wallet}) sendGift({
    required String streamId,
    required String giftCode,
    required int quantity,
  }) {
    final _DemoRoom room = _require(streamId);
    final GiftEntity gift = DemoCatalogue.gifts.firstWhere(
      (GiftEntity item) => item.code == giftCode,
      orElse: () => throw const NotFoundFailure('That gift is not available'),
    );

    final int qty = quantity.clamp(1, 99);
    final int cost = gift.coinCost * qty;
    if (_wallet.coinBalance < cost) {
      throw InsufficientBalanceFailure(
        'Not enough coins for this gift',
        requiredCoins: cost,
        availableCoins: _wallet.coinBalance,
      );
    }

    _wallet = WalletEntity(
      coinBalance: _wallet.coinBalance - cost,
      diamondBalance: _wallet.diamondBalance,
      lifetimeCoinsSpent: _wallet.lifetimeCoinsSpent + cost,
      lifetimeDiamondsEarned: _wallet.lifetimeDiamondsEarned,
    );

    // _recordGift pays the host, and when the host is you that is the other
    // half of sending a gift to yourself: coins out, diamonds back.
    final GiftEventEntity event = _recordGift(
      room: room,
      sender: me,
      gift: gift,
      quantity: qty,
    );
    _emit(LiveEvents.walletUpdated, _walletJson(_wallet));
    return (event: event, wallet: _wallet);
  }

  List<LeaderboardEntryEntity> streamLeaderboard(
    String streamId, {
    int? limit,
  }) => _leaderboardFor(_require(streamId), limit: limit ?? 10);

  List<LeaderboardEntryEntity> globalLeaderboard({
    String board = 'hosts',
    String window = 'weekly',
    int? limit,
  }) {
    final Map<String, _Tally> totals = <String, _Tally>{};

    for (final _DemoRoom room in _rooms.values) {
      if (board == 'hosts') {
        final _Tally tally = totals.putIfAbsent(
          room.host.id,
          () => _Tally(room.host),
        );
        tally.coins += room.totalCoins;
        tally.diamonds += room.totalCoins ~/ 2;
        tally.giftCount += room.totalGifts;
      } else {
        for (final _Tally gifter in room.gifters.values) {
          final _Tally tally = totals.putIfAbsent(
            gifter.user.id,
            () => _Tally(gifter.user),
          );
          tally.coins += gifter.coins;
          tally.diamonds += gifter.diamonds;
          tally.giftCount += gifter.giftCount;
        }
      }
    }

    return _rank(totals.values.toList(), limit ?? 10);
  }

  // ---------------------------------------------------------------------------
  // Wallet
  // ---------------------------------------------------------------------------

  WalletEntity topUp(String packageId) {
    final CoinPackageEntity package = DemoCatalogue.coinPackages.firstWhere(
      (CoinPackageEntity item) => item.id == packageId,
      orElse: () => throw const NotFoundFailure('Unknown coin package'),
    );
    _wallet = WalletEntity(
      coinBalance: _wallet.coinBalance + package.coins,
      diamondBalance: _wallet.diamondBalance,
      lifetimeCoinsSpent: _wallet.lifetimeCoinsSpent,
      lifetimeDiamondsEarned: _wallet.lifetimeDiamondsEarned,
    );
    _emit(LiveEvents.walletUpdated, _walletJson(_wallet));
    return _wallet;
  }

  // ---------------------------------------------------------------------------
  // The crowd
  //
  // A room with a silent audience reads as broken rather than quiet, so an
  // active room gets a paced trickle of arrivals, chat, hearts and gifts.
  // Only rooms somebody is actually inside are simulated, so an idle app is
  // not running timers for six rooms at once.
  // ---------------------------------------------------------------------------

  void _startSimulation(_DemoRoom room) {
    if (room.simulation != null || room.status != LiveStreamStatus.live) {
      return;
    }
    room.simulation = Timer.periodic(
      const Duration(milliseconds: 2600),
      (_) => _tick(room),
    );
  }

  void _stopSimulation(_DemoRoom room) {
    room.simulation?.cancel();
    room.simulation = null;
  }

  void _tick(_DemoRoom room) {
    if (room.status != LiveStreamStatus.live) {
      _stopSimulation(room);
      return;
    }

    final int roll = _random.nextInt(100);
    if (roll < 38) {
      _botChat(room);
    } else if (roll < 60) {
      _botJoin(room);
    } else if (roll < 80) {
      _botReaction(room);
    } else if (roll < 90) {
      _botGift(room);
    } else {
      _botLeave(room);
    }

    // Stats are pushed on their own cadence by the server; mirroring that
    // keeps the viewer counter alive between arrivals.
    _emit(LiveEvents.streamStats, <String, dynamic>{
      'streamId': room.id,
      'viewerCount': room.viewerCount,
      'totalLikes': room.totalLikes,
    });
  }

  UserProfileEntity _randomBot() =>
      DemoCatalogue.crowd[_random.nextInt(DemoCatalogue.crowd.length)];

  void _botChat(_DemoRoom room) {
    final ChatMessageEntity message = ChatMessageEntity(
      id: _nextId('msg'),
      streamId: room.id,
      body: DemoCatalogue
          .chatLines[_random.nextInt(DemoCatalogue.chatLines.length)],
      kind: ChatMessageKind.text,
      createdAt: DateTime.now(),
      sender: _randomBot(),
    );
    _appendMessage(room, message);
    _emit(LiveEvents.chatMessage, _chatJson(message));
  }

  void _botJoin(_DemoRoom room) {
    final UserProfileEntity viewer = _randomBot();
    room.viewerCount += 1;
    room.peakViewerCount = max(room.peakViewerCount, room.viewerCount);
    _emit(LiveEvents.viewerJoined, <String, dynamic>{
      'streamId': room.id,
      'viewerCount': room.viewerCount,
      'viewer': _userJson(viewer),
    });
  }

  void _botLeave(_DemoRoom room) {
    if (room.viewerCount <= 1) {
      return;
    }
    final UserProfileEntity viewer = _randomBot();
    room.viewerCount -= 1;
    _emit(LiveEvents.viewerLeft, <String, dynamic>{
      'streamId': room.id,
      'viewerCount': room.viewerCount,
      'viewerId': viewer.id,
    });
  }

  void _botReaction(_DemoRoom room) {
    final int count = 1 + _random.nextInt(6);
    room.totalLikes += count;
    _emit(LiveEvents.reactionBurst, <String, dynamic>{
      'streamId': room.id,
      'senderId': _randomBot().id,
      'count': count,
      'totalLikes': room.totalLikes,
    });
  }

  /// Weighted towards the cheaper tiers: a legendary takeover every few
  /// seconds would bury the room it is supposed to celebrate.
  void _botGift(_DemoRoom room) {
    final int roll = _random.nextInt(100);
    final GiftTier tier = roll < 62
        ? GiftTier.basic
        : roll < 90
        ? GiftTier.rare
        : roll < 98
        ? GiftTier.epic
        : GiftTier.legendary;
    final List<GiftEntity> pool = DemoCatalogue.gifts
        .where((GiftEntity gift) => gift.tier == tier)
        .toList();
    _recordGift(
      room: room,
      sender: _randomBot(),
      gift: pool[_random.nextInt(pool.length)],
      quantity: tier == GiftTier.basic ? 1 + _random.nextInt(5) : 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared write paths
  // ---------------------------------------------------------------------------

  /// The single place a gift changes room state, so a bot's gift and the
  /// user's gift produce exactly the same totals, podium and broadcast.
  GiftEventEntity _recordGift({
    required _DemoRoom room,
    required UserProfileEntity sender,
    required GiftEntity gift,
    required int quantity,
  }) {
    final int cost = gift.coinCost * quantity;
    room.totalCoins += cost;
    room.totalGifts += quantity;

    final _Tally tally = room.gifters.putIfAbsent(
      sender.id,
      () => _Tally(sender),
    );
    tally.coins += cost;
    tally.diamonds += cost ~/ 2;
    tally.giftCount += quantity;

    // Half the coins become the host's diamonds. While you are the host that
    // is your own wallet, whether the gift came from the crowd or from you.
    if (room.isMine) {
      _wallet = WalletEntity(
        coinBalance: _wallet.coinBalance,
        diamondBalance: _wallet.diamondBalance + cost ~/ 2,
        lifetimeCoinsSpent: _wallet.lifetimeCoinsSpent,
        lifetimeDiamondsEarned: _wallet.lifetimeDiamondsEarned + cost ~/ 2,
      );
      _emit(LiveEvents.walletUpdated, _walletJson(_wallet));
    }

    final GiftEventEntity event = GiftEventEntity(
      id: _nextId('gift'),
      streamId: room.id,
      quantity: quantity,
      coinCost: cost,
      createdAt: DateTime.now(),
      gift: gift,
      sender: sender,
      comboKey: '${sender.id}-${gift.code}',
      animationDurationMs: gift.animationDurationMs,
    );

    _emit(LiveEvents.giftReceived, <String, dynamic>{
      ..._giftEventJson(event),
      'streamTotals': <String, dynamic>{
        'totalCoins': room.totalCoins,
        'totalGifts': room.totalGifts,
      },
      'topGifters': _leaderboardFor(
        room,
        limit: 3,
      ).map(_leaderboardJson).toList(growable: false),
    });
    return event;
  }

  void _appendMessage(_DemoRoom room, ChatMessageEntity message) {
    room.messages.add(message);
    if (room.messages.length > 120) {
      room.messages.removeRange(0, room.messages.length - 120);
    }
  }

  List<LeaderboardEntryEntity> _leaderboardFor(
    _DemoRoom room, {
    int limit = 10,
  }) => _rank(room.gifters.values.toList(), limit);

  List<LeaderboardEntryEntity> _rank(List<_Tally> tallies, int limit) {
    tallies.sort((_Tally a, _Tally b) => b.coins.compareTo(a.coins));
    final int count = min(limit, tallies.length);
    return <LeaderboardEntryEntity>[
      for (int index = 0; index < count; index++)
        LeaderboardEntryEntity(
          rank: index + 1,
          user: tallies[index].user,
          totalCoins: tallies[index].coins,
          totalDiamonds: tallies[index].diamonds,
          giftCount: tallies[index].giftCount,
        ),
    ];
  }

  _DemoRoom _require(String streamId) {
    final _DemoRoom? room = _rooms[streamId];
    if (room == null) {
      throw const NotFoundFailure('This live is no longer available');
    }
    return room;
  }

  /// Local rooms are always "mock" credentials. That is not a limitation being
  /// papered over: a host publishes from the device camera straight to the
  /// screen, and a seeded room plays its bundled clip, so no SFU is involved
  /// on either side.
  RtcCredentialsEntity _credentials(_DemoRoom room, {required String role}) =>
      RtcCredentialsEntity(
        provider: 'mock',
        serverUrl: '',
        localServerUrl: '',
        channelName: room.channelName,
        uid: room.id.hashCode & 0x7fffffff,
        token: 'demo-token',
        role: role,
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );

  /// Stops every room's crowd. Nothing else holds a timer, so this leaves the
  /// backend inert without discarding its state.
  void shutdown() {
    for (final _DemoRoom room in _rooms.values) {
      _stopSimulation(room);
    }
  }

  void _emit(String name, Map<String, dynamic> payload) {
    if (!_events.isClosed) {
      _events.add(LiveRealtimeEvent(name, payload));
    }
  }

  // ---------------------------------------------------------------------------
  // Seed
  // ---------------------------------------------------------------------------

  void _seedRooms() {
    final DateTime now = DateTime.now();
    final List<_Seed> seeds = <_Seed>[
      _Seed(
        'Lina Live',
        'lina.live',
        'demo-bot-lina',
        'LIVE • Amman Night Café',
        'coffee',
        128,
        24600,
        41200,
        46,
      ),
      _Seed(
        'Omar',
        'omar.hoops',
        'demo-bot-omar',
        'آخر ربع ومباراة مجنونة 🏀',
        'basketball',
        341,
        51900,
        88500,
        92,
      ),
      _Seed(
        'Maya',
        'blue.maya',
        'demo-bot-maya',
        'Deep blue • whale watching live',
        'whale',
        92,
        12400,
        19800,
        27,
      ),
      _Seed(
        'Ali',
        'ride.ali',
        'demo-bot-ali',
        'رحلة وادي رم على الدراجة',
        'motorcycle',
        214,
        33100,
        52700,
        61,
      ),
      _Seed(
        'Nour',
        'nour.jo',
        'demo-bot-nour',
        'غروب البتراء بث مباشر',
        'petra',
        176,
        28800,
        47300,
        55,
      ),
      _Seed(
        'Sara',
        'sara.q',
        'demo-bot-sara',
        'مطبخي اليوم • وصفة سريعة',
        'healthy-food',
        143,
        19700,
        31600,
        38,
      ),
    ];

    for (int index = 0; index < seeds.length; index++) {
      final _Seed seed = seeds[index];
      final String id = 'demo-room-${seed.asset}';
      final UserProfileEntity host = UserProfileEntity(
        id: seed.hostId,
        username: seed.username,
        displayName: seed.displayName,
      );
      final _DemoRoom room =
          _DemoRoom(
              id: id,
              title: seed.title,
              host: host,
              coverUrl: 'asset://assets/demo/feed/${seed.asset}.jpg',
              channelName: 'demo_${seed.asset}',
              // Staggered so the feed's "newest first" order is stable and the
              // elapsed timers do not all read the same value.
              startedAt: now.subtract(Duration(minutes: 12 + index * 9)),
              isMine: false,
              isDemo: true,
              demoVideoAsset: 'assets/demo/feed/${seed.asset}.mp4',
            )
            ..viewerCount = seed.viewers
            ..peakViewerCount = (seed.viewers * 1.4).round()
            ..totalLikes = seed.likes
            ..totalCoins = seed.coins
            ..totalGifts = seed.giftCount;

      // A podium that is already populated, so the top-gifters bar is not
      // empty for the first minute of every room.
      for (int rank = 0; rank < 3; rank++) {
        final UserProfileEntity gifter = DemoCatalogue
            .crowd[(index * 3 + rank) % DemoCatalogue.crowd.length];
        room.gifters[gifter.id] = _Tally(gifter)
          ..coins = (seed.coins * (0.34 - rank * 0.09)).round()
          ..diamonds = (seed.coins * (0.17 - rank * 0.045)).round()
          ..giftCount = (seed.giftCount * (0.3 - rank * 0.08)).round();
      }

      for (int line = 0; line < 5; line++) {
        room.messages.add(
          ChatMessageEntity(
            id: '$id-seed-$line',
            streamId: id,
            body: DemoCatalogue
                .chatLines[(index * 5 + line) % DemoCatalogue.chatLines.length],
            kind: ChatMessageKind.text,
            createdAt: now.subtract(Duration(seconds: 60 - line * 11)),
            sender: DemoCatalogue
                .crowd[(index * 4 + line) % DemoCatalogue.crowd.length],
          ),
        );
      }

      _rooms[id] = room;
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime payload shapes
  //
  // The controllers parse these with the same model extensions they use for
  // server frames, so the demo cannot drift into a shape the API never sends.
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _userJson(UserProfileEntity user) =>
      <String, dynamic>{
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'avatarUrl': user.avatarUrl,
        'bio': user.bio,
      };

  static Map<String, dynamic> _walletJson(WalletEntity wallet) =>
      <String, dynamic>{
        'coinBalance': wallet.coinBalance,
        'diamondBalance': wallet.diamondBalance,
        'lifetimeCoinsSpent': wallet.lifetimeCoinsSpent,
        'lifetimeDiamondsEarned': wallet.lifetimeDiamondsEarned,
      };

  static Map<String, dynamic> _chatJson(ChatMessageEntity message) =>
      <String, dynamic>{
        'id': message.id,
        'streamId': message.streamId,
        'body': message.body,
        'kind': message.kind.name,
        'createdAt': message.createdAt.toIso8601String(),
        'sender': _userJson(message.sender),
      };

  static Map<String, dynamic> _giftJson(GiftEntity gift) => <String, dynamic>{
    'id': gift.id,
    'code': gift.code,
    'name': gift.name,
    'nameAr': gift.nameAr,
    'coinCost': gift.coinCost,
    'tier': gift.tier.name,
    'animationDurationMs': gift.animationDurationMs,
    'animationType': gift.animationType,
    'iconUrl': gift.iconUrl,
    'animationAsset': gift.animationAsset,
  };

  static Map<String, dynamic> _giftEventJson(GiftEventEntity event) =>
      <String, dynamic>{
        'id': event.id,
        'streamId': event.streamId,
        'quantity': event.quantity,
        'coinCost': event.coinCost,
        'createdAt': event.createdAt.toIso8601String(),
        'comboKey': event.comboKey,
        'animationDurationMs': event.animationDurationMs,
        'gift': _giftJson(event.gift),
        'sender': _userJson(event.sender),
      };

  static Map<String, dynamic> _leaderboardJson(LeaderboardEntryEntity entry) =>
      <String, dynamic>{
        'rank': entry.rank,
        'user': _userJson(entry.user),
        'totalCoins': entry.totalCoins,
        'totalDiamonds': entry.totalDiamonds,
        'giftCount': entry.giftCount,
      };

  static Map<String, dynamic> _streamJson(_DemoRoom room) => <String, dynamic>{
    'id': room.id,
    'title': room.title,
    'status': room.status.name,
    'viewerCount': room.viewerCount,
    'totalLikes': room.totalLikes,
    'totalCoins': room.totalCoins,
    'totalGifts': room.totalGifts,
    'startedAt': room.startedAt.toIso8601String(),
    'host': _userJson(room.host),
    'coverUrl': room.coverUrl,
    'channelName': room.channelName,
    'peakViewerCount': room.peakViewerCount,
    'isDemo': room.isDemo,
    'demoVideoAsset': room.demoVideoAsset,
  };
}

/// One room's mutable state. The entity handed to the UI is rebuilt from this
/// on every read, which is why counters can move without any copyWith dance.
class _DemoRoom {
  _DemoRoom({
    required this.id,
    required this.title,
    required this.host,
    required this.channelName,
    required this.startedAt,
    required this.isMine,
    this.coverUrl,
    this.isDemo = false,
    this.demoVideoAsset,
  });

  final String id;
  final String title;
  final UserProfileEntity host;
  final String channelName;
  final DateTime startedAt;

  /// True for the room this device is broadcasting. It decides whether gift
  /// earnings land in the local wallet and whether the room survives its end.
  final bool isMine;
  final String? coverUrl;

  /// A seeded room plays a bundled clip instead of a live track, which is what
  /// lets one phone watch a "broadcast" with no second device involved.
  final bool isDemo;
  final String? demoVideoAsset;

  LiveStreamStatus status = LiveStreamStatus.live;
  DateTime? endedAt;
  DateTime lastHeartbeat = DateTime.now();
  int viewerCount = 0;
  int peakViewerCount = 0;
  int totalLikes = 0;
  int totalCoins = 0;
  int totalGifts = 0;

  final List<ChatMessageEntity> messages = <ChatMessageEntity>[];
  final Map<String, _Tally> gifters = <String, _Tally>{};
  Timer? simulation;

  LiveStreamEntity toEntity() => LiveStreamEntity(
    id: id,
    title: title,
    status: status,
    viewerCount: viewerCount,
    totalLikes: totalLikes,
    totalCoins: totalCoins,
    startedAt: startedAt,
    host: host,
    coverUrl: coverUrl,
    channelName: channelName,
    peakViewerCount: peakViewerCount,
    totalGifts: totalGifts,
    durationSeconds: (endedAt ?? DateTime.now())
        .difference(startedAt)
        .inSeconds,
    endedAt: endedAt,
    isDemo: isDemo,
    demoVideoAsset: demoVideoAsset,
  );
}

class _Tally {
  _Tally(this.user);

  final UserProfileEntity user;
  int coins = 0;
  int diamonds = 0;
  int giftCount = 0;
}

class _Seed {
  const _Seed(
    this.displayName,
    this.username,
    this.hostId,
    this.title,
    this.asset,
    this.viewers,
    this.likes,
    this.coins,
    this.giftCount,
  );

  final String displayName;
  final String username;
  final String hostId;
  final String title;
  final String asset;
  final int viewers;
  final int likes;
  final int coins;
  final int giftCount;
}
