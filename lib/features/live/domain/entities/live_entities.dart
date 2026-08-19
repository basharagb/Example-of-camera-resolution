import 'package:flutter/foundation.dart';

/// Immutable domain models for the live feature. They carry no JSON knowledge:
/// parsing lives in the data layer's models, so a server field rename never
/// reaches the widgets.

@immutable
class UserProfileEntity {
  const UserProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;

  /// Fallback avatar: the first letter of the display name, uppercased.
  String get initial {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

@immutable
class WalletEntity {
  const WalletEntity({
    required this.coinBalance,
    required this.diamondBalance,
    required this.lifetimeCoinsSpent,
    required this.lifetimeDiamondsEarned,
  });

  const WalletEntity.empty()
    : coinBalance = 0,
      diamondBalance = 0,
      lifetimeCoinsSpent = 0,
      lifetimeDiamondsEarned = 0;

  final int coinBalance;
  final int diamondBalance;
  final int lifetimeCoinsSpent;
  final int lifetimeDiamondsEarned;

  bool canAfford(int coins) => coinBalance >= coins;
}

enum LiveStreamStatus { live, ended }

@immutable
class LiveStreamEntity {
  const LiveStreamEntity({
    required this.id,
    required this.title,
    required this.status,
    required this.viewerCount,
    required this.totalLikes,
    required this.totalCoins,
    required this.startedAt,
    required this.host,
    this.coverUrl,
    this.channelName,
    this.peakViewerCount = 0,
    this.totalGifts = 0,
    this.durationSeconds = 0,
    this.endedAt,
  });

  final String id;
  final String title;
  final LiveStreamStatus status;
  final int viewerCount;
  final int totalLikes;
  final int totalCoins;
  final DateTime startedAt;
  final UserProfileEntity host;
  final String? coverUrl;
  final String? channelName;
  final int peakViewerCount;
  final int totalGifts;
  final int durationSeconds;
  final DateTime? endedAt;

  bool get isLive => status == LiveStreamStatus.live;

  Duration get elapsed => isLive
      ? DateTime.now().difference(startedAt)
      : Duration(seconds: durationSeconds);

  LiveStreamEntity copyWith({
    int? viewerCount,
    int? totalLikes,
    int? totalCoins,
    int? totalGifts,
    LiveStreamStatus? status,
  }) => LiveStreamEntity(
    id: id,
    title: title,
    status: status ?? this.status,
    viewerCount: viewerCount ?? this.viewerCount,
    totalLikes: totalLikes ?? this.totalLikes,
    totalCoins: totalCoins ?? this.totalCoins,
    startedAt: startedAt,
    host: host,
    coverUrl: coverUrl,
    channelName: channelName,
    peakViewerCount: peakViewerCount,
    totalGifts: totalGifts ?? this.totalGifts,
    durationSeconds: durationSeconds,
    endedAt: endedAt,
  );
}

/// Credentials the media SDK needs to publish to or subscribe from a channel.
/// The app never holds the vendor certificate; only this short lived token.
@immutable
class RtcCredentialsEntity {
  const RtcCredentialsEntity({
    required this.provider,
    required this.serverUrl,
    required this.localServerUrl,
    required this.channelName,
    required this.uid,
    required this.token,
    required this.role,
    required this.expiresAt,
  });

  final String provider;
  final String serverUrl;
  final String localServerUrl;
  final String channelName;
  final int uid;
  final String token;
  final String role;
  final DateTime expiresAt;

  bool get isHost => role == 'host';

  /// True when the backend is running without vendor credentials. The UI shows
  /// a placeholder surface instead of pretending to render video.
  bool get isMock => provider == 'mock';
}

enum GiftTier { basic, rare, epic, legendary }

@immutable
class GiftEntity {
  const GiftEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.nameAr,
    required this.coinCost,
    required this.tier,
    required this.animationDurationMs,
    this.animationType = 'float',
    this.iconUrl,
    this.animationAsset,
  });

  final String id;
  final String code;
  final String name;
  final String nameAr;
  final int coinCost;
  final GiftTier tier;
  final int animationDurationMs;
  final String animationType;
  final String? iconUrl;
  final String? animationAsset;

  String? get artwork => animationAsset ?? iconUrl;
}

@immutable
class GiftEventEntity {
  const GiftEventEntity({
    required this.id,
    required this.streamId,
    required this.quantity,
    required this.coinCost,
    required this.createdAt,
    required this.gift,
    required this.sender,
    this.comboKey,
    this.animationDurationMs = 2000,
  });

  final String id;
  final String streamId;
  final int quantity;
  final int coinCost;
  final DateTime createdAt;
  final GiftEntity gift;
  final UserProfileEntity sender;
  final String? comboKey;
  final int animationDurationMs;

  Duration get animationDuration => Duration(milliseconds: animationDurationMs);
}

enum ChatMessageKind { text, join, system }

@immutable
class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.streamId,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.sender,
  });

  final String id;
  final String streamId;
  final String? body;
  final ChatMessageKind kind;
  final DateTime createdAt;
  final UserProfileEntity sender;
}

@immutable
class LeaderboardEntryEntity {
  const LeaderboardEntryEntity({
    required this.rank,
    required this.user,
    required this.totalCoins,
    required this.totalDiamonds,
    required this.giftCount,
  });

  final int rank;
  final UserProfileEntity user;
  final int totalCoins;
  final int totalDiamonds;
  final int giftCount;
}

@immutable
class CoinPackageEntity {
  const CoinPackageEntity({
    required this.id,
    required this.label,
    required this.coins,
    required this.priceUsd,
  });

  final String id;
  final String label;
  final int coins;
  final double priceUsd;
}

/// Everything needed to render a room the moment it opens: the stream, the
/// media credentials, and the conversation already in progress.
@immutable
class LiveRoomSessionEntity {
  const LiveRoomSessionEntity({
    required this.stream,
    required this.rtc,
    required this.role,
    required this.recentMessages,
    required this.topGifters,
  });

  final LiveStreamEntity stream;
  final RtcCredentialsEntity rtc;
  final String role;
  final List<ChatMessageEntity> recentMessages;
  final List<LeaderboardEntryEntity> topGifters;

  bool get isHost => role == 'host';
}

@immutable
class AuthSessionEntity {
  const AuthSessionEntity({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserProfileEntity user;
  final String accessToken;
  final String refreshToken;
}

@immutable
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  const PagedResult.empty()
    : items = const <Never>[],
      page = 1,
      total = 0,
      hasMore = false;

  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;
}
