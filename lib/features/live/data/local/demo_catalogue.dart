import '../../domain/entities/live_entities.dart';

/// The catalogue the on-device demo backend serves.
///
/// It mirrors the server seed one-for-one - same codes, same prices, same
/// artwork paths - so a build running against the local backend and a build
/// running against the API show an identical grid.
abstract final class DemoCatalogue {
  static String _art(String name) => 'assets/demo/gifts/$name.png';

  static GiftEntity _gift({
    required String code,
    required String name,
    required String nameAr,
    required int coinCost,
    required GiftTier tier,
    required String artwork,
    required String animationType,
    required int animationDurationMs,
  }) => GiftEntity(
    id: 'gift-$code',
    code: code,
    name: name,
    nameAr: nameAr,
    coinCost: coinCost,
    tier: tier,
    animationDurationMs: animationDurationMs,
    animationType: animationType,
    iconUrl: _art(artwork),
    animationAsset: _art(artwork),
  );

  /// Prices climb roughly ten-fold per tier, so the distance between a rose
  /// and a castle is felt in the wallet as well as on screen.
  static final List<GiftEntity> gifts = <GiftEntity>[
    // Basic: cheap enough to spam, short animation.
    _gift(
      code: 'rose',
      name: 'Rose',
      nameAr: 'وردة',
      coinCost: 1,
      tier: GiftTier.basic,
      artwork: 'rose',
      animationType: 'float',
      animationDurationMs: 1200,
    ),
    _gift(
      code: 'heart',
      name: 'Heart',
      nameAr: 'قلب',
      coinCost: 5,
      tier: GiftTier.basic,
      artwork: 'heart',
      animationType: 'float',
      animationDurationMs: 1200,
    ),
    _gift(
      code: 'coffee',
      name: 'Coffee',
      nameAr: 'قهوة',
      coinCost: 10,
      tier: GiftTier.basic,
      artwork: 'coffee',
      animationType: 'float',
      animationDurationMs: 1400,
    ),
    _gift(
      code: 'ice_cream',
      name: 'Ice Cream',
      nameAr: 'آيس كريم',
      coinCost: 15,
      tier: GiftTier.basic,
      artwork: 'ice-cream',
      animationType: 'float',
      animationDurationMs: 1400,
    ),
    _gift(
      code: 'star',
      name: 'Star',
      nameAr: 'نجمة',
      coinCost: 20,
      tier: GiftTier.basic,
      artwork: 'star',
      animationType: 'float',
      animationDurationMs: 1500,
    ),

    // Rare: a visible banner across the chat.
    _gift(
      code: 'perfume',
      name: 'Perfume',
      nameAr: 'عطر',
      coinCost: 50,
      tier: GiftTier.rare,
      artwork: 'perfume',
      animationType: 'banner',
      animationDurationMs: 2000,
    ),
    _gift(
      code: 'crown',
      name: 'Crown',
      nameAr: 'تاج',
      coinCost: 100,
      tier: GiftTier.rare,
      artwork: 'crown',
      animationType: 'banner',
      animationDurationMs: 2400,
    ),
    _gift(
      code: 'fireworks',
      name: 'Fireworks',
      nameAr: 'ألعاب نارية',
      coinCost: 199,
      tier: GiftTier.rare,
      artwork: 'fireworks',
      animationType: 'fireworks',
      animationDurationMs: 2800,
    ),
    _gift(
      code: 'diamond_ring',
      name: 'Diamond Ring',
      nameAr: 'خاتم ألماس',
      coinCost: 299,
      tier: GiftTier.rare,
      artwork: 'diamond-ring',
      animationType: 'banner',
      animationDurationMs: 2800,
    ),
    _gift(
      code: 'swan',
      name: 'Swan',
      nameAr: 'بجعة',
      coinCost: 399,
      tier: GiftTier.rare,
      artwork: 'swan',
      animationType: 'sail',
      animationDurationMs: 3000,
    ),

    // Epic: full width takeover.
    _gift(
      code: 'sports_car',
      name: 'Sports Car',
      nameAr: 'سيارة رياضية',
      coinCost: 999,
      tier: GiftTier.epic,
      artwork: 'sports-car',
      animationType: 'drive',
      animationDurationMs: 3800,
    ),
    _gift(
      code: 'motorcycle',
      name: 'Motorcycle',
      nameAr: 'دراجة نارية',
      coinCost: 1299,
      tier: GiftTier.epic,
      artwork: 'motorcycle',
      animationType: 'drive',
      animationDurationMs: 3900,
    ),
    _gift(
      code: 'yacht',
      name: 'Yacht',
      nameAr: 'يخت',
      coinCost: 1999,
      tier: GiftTier.epic,
      artwork: 'yacht',
      animationType: 'sail',
      animationDurationMs: 4200,
    ),
    _gift(
      code: 'private_jet',
      name: 'Private Jet',
      nameAr: 'طائرة خاصة',
      coinCost: 4999,
      tier: GiftTier.epic,
      artwork: 'private-jet',
      animationType: 'fly',
      animationDurationMs: 4600,
    ),
    _gift(
      code: 'lion',
      name: 'Lion',
      nameAr: 'أسد',
      coinCost: 6999,
      tier: GiftTier.epic,
      artwork: 'lion',
      animationType: 'roar',
      animationDurationMs: 5000,
    ),
    _gift(
      code: 'black_panther',
      name: 'Black Panther',
      nameAr: 'فهد أسود',
      coinCost: 7999,
      tier: GiftTier.epic,
      artwork: 'black-panther',
      animationType: 'prowl',
      animationDurationMs: 5000,
    ),

    // Legendary: the screen belongs to the sender.
    _gift(
      code: 'whale',
      name: 'Whale',
      nameAr: 'حوت',
      coinCost: 9999,
      tier: GiftTier.legendary,
      artwork: 'whale',
      animationType: 'swim',
      animationDurationMs: 5600,
    ),
    _gift(
      code: 'golden_whale',
      name: 'Golden Whale',
      nameAr: 'الحوت الذهبي',
      coinCost: 14999,
      tier: GiftTier.legendary,
      artwork: 'golden-whale',
      animationType: 'swim',
      animationDurationMs: 6000,
    ),
    _gift(
      code: 'dragon',
      name: 'Dragon',
      nameAr: 'تنين',
      coinCost: 17999,
      tier: GiftTier.legendary,
      artwork: 'dragon',
      animationType: 'fly',
      animationDurationMs: 6200,
    ),
    _gift(
      code: 'castle',
      name: 'Castle',
      nameAr: 'قلعة',
      coinCost: 19999,
      tier: GiftTier.legendary,
      artwork: 'castle',
      animationType: 'takeover',
      animationDurationMs: 6500,
    ),
    _gift(
      code: 'universe',
      name: 'Universe',
      nameAr: 'الكون',
      coinCost: 29999,
      tier: GiftTier.legendary,
      artwork: 'universe',
      animationType: 'galaxy',
      animationDurationMs: 7000,
    ),
  ];

  /// Top ups are instant and free in the demo: no store, no payment sheet.
  static const List<CoinPackageEntity> coinPackages = <CoinPackageEntity>[
    CoinPackageEntity(
      id: 'coins_100',
      label: '100 coins',
      coins: 100,
      priceUsd: 0.99,
    ),
    CoinPackageEntity(
      id: 'coins_500',
      label: '500 coins',
      coins: 500,
      priceUsd: 4.99,
    ),
    CoinPackageEntity(
      id: 'coins_1200',
      label: '1,200 coins',
      coins: 1200,
      priceUsd: 9.99,
    ),
    CoinPackageEntity(
      id: 'coins_3000',
      label: '3,000 coins',
      coins: 3000,
      priceUsd: 24.99,
    ),
    CoinPackageEntity(
      id: 'coins_7000',
      label: '7,000 coins',
      coins: 7000,
      priceUsd: 49.99,
    ),
    CoinPackageEntity(
      id: 'coins_15000',
      label: '15,000 coins',
      coins: 15000,
      priceUsd: 99.99,
    ),
  ];

  /// The account the demo is signed in as. There is no password anywhere in
  /// the local build; this profile simply exists from the first frame.
  static const UserProfileEntity localUser = UserProfileEntity(
    id: 'demo-user-local',
    username: 'bashar',
    displayName: 'Bashar',
    bio: 'Demo account • everything runs on this device',
  );

  /// Bots that populate a room: they chat, react and send gifts so a demo
  /// never looks like an empty channel.
  static const List<UserProfileEntity> crowd = <UserProfileEntity>[
    UserProfileEntity(
      id: 'demo-bot-sara',
      username: 'sara.q',
      displayName: 'Sara',
    ),
    UserProfileEntity(
      id: 'demo-bot-omar',
      username: 'omar.hoops',
      displayName: 'Omar',
    ),
    UserProfileEntity(
      id: 'demo-bot-lina',
      username: 'lina.live',
      displayName: 'Lina',
    ),
    UserProfileEntity(
      id: 'demo-bot-maya',
      username: 'blue.maya',
      displayName: 'Maya',
    ),
    UserProfileEntity(
      id: 'demo-bot-ali',
      username: 'ride.ali',
      displayName: 'Ali',
    ),
    UserProfileEntity(
      id: 'demo-bot-nour',
      username: 'nour.jo',
      displayName: 'Nour',
    ),
    UserProfileEntity(
      id: 'demo-bot-yara',
      username: 'yara.x',
      displayName: 'Yara',
    ),
    UserProfileEntity(
      id: 'demo-bot-khaled',
      username: 'khaled.k',
      displayName: 'Khaled',
    ),
    UserProfileEntity(
      id: 'demo-bot-rami',
      username: 'rami.dev',
      displayName: 'Rami',
    ),
    UserProfileEntity(
      id: 'demo-bot-huda',
      username: 'huda.h',
      displayName: 'Huda',
    ),
  ];

  static const List<String> chatLines = <String>[
    'شو هالجو 🔥',
    'مساء الخير من عمّان',
    'الصوت واضح والصورة نار',
    'first time here, love it',
    'كمّل كمّل 👏',
    'من وين انت؟',
    'هاد البث أحلى شي اليوم',
    'sound quality is great',
    'ارفع الصوت شوي',
    'واو 😍',
    'من الأردن ❤️',
    'greetings from Dubai',
    'شكراً على البث',
    'كم باقي على النهاية؟',
    'الله يعطيك العافية',
    'this is so relaxing',
    'ردّ على تعليقي 🙋',
    'أول مرة بحضر لك',
    'نار نار نار 🔥🔥',
    'متابع من زمان',
  ];
}
