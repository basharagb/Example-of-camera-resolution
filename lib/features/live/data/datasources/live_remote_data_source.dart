import '../../../../core/services/network/api_client.dart';

/// The only place that knows the shape of the REST surface. Repositories call
/// these methods and map the resulting JSON into entities; nothing above this
/// file mentions a path or a query parameter.
class LiveRemoteDataSource {
  const LiveRemoteDataSource(this._client);

  final ApiClient _client;

  // ---- auth ----

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      _client.post('/auth/register', body: body, authenticated: false);

  Future<Map<String, dynamic>> login(Map<String, dynamic> body) =>
      _client.post('/auth/login', body: body, authenticated: false);

  Future<Map<String, dynamic>> me() => _client.get('/auth/me');

  // ---- streams ----

  Future<Map<String, dynamic>> listStreams({int page = 1, int pageSize = 20}) =>
      _client.get(
        '/streams',
        query: <String, dynamic>{'page': page, 'pageSize': pageSize},
        authenticated: false,
      );

  Future<Map<String, dynamic>> getStream(String streamId) =>
      _client.get('/streams/$streamId', authenticated: false);

  Future<Map<String, dynamic>> startStream(Map<String, dynamic> body) =>
      _client.post('/streams', body: body);

  Future<Map<String, dynamic>> joinStream(String streamId) =>
      _client.post('/streams/$streamId/join');

  Future<Map<String, dynamic>> endStream(String streamId) =>
      _client.post('/streams/$streamId/end');

  Future<Map<String, dynamic>> heartbeat(String streamId) =>
      _client.post('/streams/$streamId/heartbeat');

  Future<Map<String, dynamic>> sendReaction(String streamId, int count) =>
      _client.post(
        '/streams/$streamId/reactions',
        body: <String, dynamic>{'count': count},
      );

  // ---- chat ----

  Future<Map<String, dynamic>> chatHistory(String streamId, {int? limit}) =>
      _client.get(
        '/streams/$streamId/messages',
        query: <String, dynamic>{'limit': ?limit},
        authenticated: false,
      );

  Future<Map<String, dynamic>> sendChat(String streamId, String body) =>
      _client.post(
        '/streams/$streamId/messages',
        body: <String, dynamic>{'body': body},
      );

  // ---- gifts ----

  Future<Map<String, dynamic>> gifts() => _client.get('/gifts', authenticated: false);

  Future<Map<String, dynamic>> sendGift(
    String streamId,
    String giftCode,
    int quantity,
    String idempotencyKey,
  ) => _client.post(
    '/streams/$streamId/gifts',
    body: <String, dynamic>{
      'giftCode': giftCode,
      'quantity': quantity,
      'idempotencyKey': idempotencyKey,
    },
  );

  Future<Map<String, dynamic>> streamLeaderboard(String streamId, {int? limit}) =>
      _client.get(
        '/streams/$streamId/leaderboard',
        query: <String, dynamic>{'limit': ?limit},
        authenticated: false,
      );

  Future<Map<String, dynamic>> globalLeaderboard({
    String board = 'hosts',
    String window = 'weekly',
    int? limit,
  }) => _client.get(
    '/leaderboard',
    query: <String, dynamic>{
      'board': board,
      'window': window,
      'limit': ?limit,
    },
    authenticated: false,
  );

  // ---- wallet ----

  Future<Map<String, dynamic>> wallet() => _client.get('/wallet');

  Future<Map<String, dynamic>> coinPackages() => _client.get('/wallet/packages');

  Future<Map<String, dynamic>> topUp(String packageId) => _client.post(
    '/wallet/topup',
    body: <String, dynamic>{'packageId': packageId},
  );
}
