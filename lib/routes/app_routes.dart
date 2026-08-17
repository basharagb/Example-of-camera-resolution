abstract final class AppRoutes {
  /// Decides between the auth screen and the feed once the stored session has
  /// been checked.
  static const String splash = '/';
  static const String auth = '/auth';
  static const String liveList = '/live';
  static const String goLive = '/live/new';
  static const String liveRoom = '/live/room';

  /// The original capability-aware camera, still reachable on its own.
  static const String camera = '/camera';
}
