import 'package:apex_camera/core/errors/failures.dart';
import 'package:apex_camera/core/services/network/live_events_client.dart';
import 'package:apex_camera/features/live/data/local/demo_live_backend.dart';
import 'package:apex_camera/features/live/domain/entities/live_entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoLiveBackend backend;

  setUp(() => backend = DemoLiveBackend.forTest());
  tearDown(() => backend.shutdown());

  test('the feed is populated with bundled rooms and no network call', () {
    final PagedResult<LiveStreamEntity> page = backend.listStreams();

    expect(page.items, isNotEmpty);
    expect(page.items.every((LiveStreamEntity s) => s.isLive), isTrue);
    // Every seeded room plays a clip from the bundle, which is what lets one
    // device watch a "broadcast" with nothing else running.
    expect(
      page.items.every(
        (LiveStreamEntity s) => (s.demoVideoAsset ?? '').startsWith('assets/'),
      ),
      isTrue,
    );
  });

  test('nobody signs in: a profile and a funded wallet exist immediately', () {
    expect(backend.currentUser(), isNotNull);
    expect(backend.wallet.coinBalance, greaterThan(0));
    // Any credentials are accepted, because there is nothing to check them
    // against.
    expect(backend.signIn(identifier: 'anyone').user.username, 'anyone');
  });

  test(
    'a gift to your own room debits coins and credits diamonds back',
    () async {
      final LiveRoomSessionEntity room = backend.startBroadcast(
        title: 'Testing',
      );
      final int before = backend.wallet.coinBalance;

      final Future<LiveRealtimeEvent> broadcast = backend.events.firstWhere(
        (LiveRealtimeEvent event) => event.name == LiveEvents.giftReceived,
      );

      final ({GiftEventEntity event, WalletEntity wallet}) result = backend
          .sendGift(streamId: room.stream.id, giftCode: 'crown', quantity: 2);

      expect(result.event.coinCost, 200);
      expect(result.wallet.coinBalance, before - 200);
      // Hosting your own room means the earnings land in the same wallet, which
      // is the receiving half of sending a gift to yourself.
      expect(result.wallet.diamondBalance, 100);
      expect(result.wallet.lifetimeCoinsSpent, 200);

      final LiveRealtimeEvent event = await broadcast;
      expect(event.payload['streamId'], room.stream.id);
      expect(event.payload['quantity'], 2);

      final List<LeaderboardEntryEntity> podium = backend.streamLeaderboard(
        room.stream.id,
      );
      expect(podium.first.user.id, backend.me.id);
      expect(podium.first.totalCoins, 200);
    },
  );

  test(
    'a gift beyond the balance reports the shortfall instead of failing flat',
    () {
      final LiveRoomSessionEntity room = backend.startBroadcast(
        title: 'Testing',
      );
      // Drain the wallet with the most expensive gift the catalogue has.
      while (backend.wallet.coinBalance >= 29999) {
        backend.sendGift(
          streamId: room.stream.id,
          giftCode: 'universe',
          quantity: 1,
        );
      }

      expect(
        () => backend.sendGift(
          streamId: room.stream.id,
          giftCode: 'universe',
          quantity: 1,
        ),
        throwsA(
          isA<InsufficientBalanceFailure>().having(
            (InsufficientBalanceFailure f) => f.missingCoins,
            'missingCoins',
            greaterThan(0),
          ),
        ),
      );

      final int before = backend.wallet.coinBalance;
      expect(backend.topUp('coins_15000').coinBalance, before + 15000);
    },
  );

  test(
    'chat is echoed on the realtime feed, like the server echoes it',
    () async {
      final String streamId = backend.listStreams().items.first.id;
      backend.join(streamId);

      final Future<LiveRealtimeEvent> echo = backend.events.firstWhere(
        (LiveRealtimeEvent event) =>
            event.name == LiveEvents.chatMessage &&
            event.payload['body'] == 'مرحبا',
      );

      final ChatMessageEntity sent = backend.sendChat(streamId, 'مرحبا');

      expect((await echo).payload['id'], sent.id);
      expect(backend.chatHistory(streamId).last.id, sent.id);
    },
  );

  test('reactions accumulate and are announced with the sender', () async {
    final String streamId = backend.listStreams().items.first.id;
    final int before = backend.streamById(streamId).totalLikes;

    final Future<LiveRealtimeEvent> burst = backend.events.firstWhere(
      (LiveRealtimeEvent event) =>
          event.name == LiveEvents.reactionBurst &&
          event.payload['senderId'] == backend.me.id,
    );

    expect(backend.react(streamId, 4), before + 4);
    expect((await burst).payload['count'], 4);
  });

  test(
    'ending your broadcast announces it and clears it from the feed',
    () async {
      final LiveRoomSessionEntity room = backend.startBroadcast(
        title: 'Testing',
      );
      expect(
        backend.listStreams().items.map((LiveStreamEntity s) => s.id),
        contains(room.stream.id),
      );

      final Future<LiveRealtimeEvent> ended = backend.events.firstWhere(
        (LiveRealtimeEvent event) => event.name == LiveEvents.streamEnded,
      );

      backend.end(room.stream.id);

      expect((await ended).payload['streamId'], room.stream.id);
      expect(
        backend.listStreams().items.map((LiveStreamEntity s) => s.id),
        isNot(contains(room.stream.id)),
      );
    },
  );

  test('a room hands back mock credentials, so no SFU is ever contacted', () {
    final LiveRoomSessionEntity hosted = backend.startBroadcast(
      title: 'Testing',
    );
    expect(hosted.rtc.isMock, isTrue);
    expect(hosted.isHost, isTrue);

    final LiveRoomSessionEntity watched = backend.join(
      backend.listStreams().items.last.id,
    );
    expect(watched.rtc.isMock, isTrue);
    expect(watched.isHost, isFalse);
    // A room opens with the conversation already in progress rather than as an
    // empty screen.
    expect(watched.recentMessages, isNotEmpty);
    expect(watched.topGifters, isNotEmpty);
  });

  test('the catalogue covers every tier and prices climb with it', () {
    expect(backend.gifts.length, 21);
    for (final GiftTier tier in GiftTier.values) {
      expect(
        backend.gifts.where((GiftEntity gift) => gift.tier == tier),
        isNotEmpty,
        reason: 'the $tier tab would be empty',
      );
    }
    expect(
      backend.gifts.every(
        (GiftEntity gift) =>
            (gift.artwork ?? '').startsWith('assets/demo/gifts/'),
      ),
      isTrue,
    );
  });
}
