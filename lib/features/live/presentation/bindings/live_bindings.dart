import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';

import '../../../../core/services/network/api_client.dart';
import '../../../../core/services/network/live_events_client.dart';
import '../../../../core/services/permissions/permission_service.dart';
import '../../../../core/services/storage/token_storage.dart';
import '../../../camera/domain/repositories/permission_repository.dart';
import '../../../camera/domain/usecases/permission_usecases.dart';
import '../../data/datasources/livekit_media_engine.dart';
import '../../data/datasources/live_remote_data_source.dart';
import '../../data/repositories/live_repositories_impl.dart';
import '../../domain/repositories/live_media_engine.dart';
import '../../domain/repositories/live_repositories.dart';
import '../../domain/usecases/live_usecases.dart';
import '../controllers/live_list_controller.dart';
import '../controllers/live_room_controller.dart';
import '../controllers/session_controller.dart';

/// Registered once at startup. Everything here outlives any single screen: the
/// HTTP client, the socket, the stored session and the wallet.
class LiveCoreBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<TokenStorage>(SecureTokenStorage(), permanent: true);
    Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    Get.put<LiveEventsClient>(
      LiveEventsClient(Get.find<TokenStorage>()),
      permanent: true,
    );

    Get.put<LiveRemoteDataSource>(
      LiveRemoteDataSource(Get.find<ApiClient>()),
      permanent: true,
    );

    final LiveRemoteDataSource remote = Get.find<LiveRemoteDataSource>();
    Get.put<AuthRepository>(
      AuthRepositoryImpl(remote, Get.find<TokenStorage>()),
      permanent: true,
    );
    Get.put<LiveStreamRepository>(
      LiveStreamRepositoryImpl(remote),
      permanent: true,
    );
    Get.put<ChatRepository>(ChatRepositoryImpl(remote), permanent: true);
    Get.put<GiftRepository>(GiftRepositoryImpl(remote), permanent: true);
    Get.put<WalletRepository>(WalletRepositoryImpl(remote), permanent: true);

    // One engine instance for the whole app: the vendor SDK is a native
    // singleton, and creating a second one while the first holds the camera
    // fails on both platforms.
    Get.put<LiveMediaEngine>(LiveKitMediaEngine(), permanent: true);

    Get.put<PermissionRepository>(
      PermissionService(DeviceInfoPlugin()),
      permanent: true,
    );

    Get.put<SessionController>(
      SessionController(
        loginUser: LoginUseCase(Get.find<AuthRepository>()),
        registerUser: RegisterUseCase(Get.find<AuthRepository>()),
        getCurrentUser: GetCurrentUserUseCase(Get.find<AuthRepository>()),
        logoutUser: LogoutUseCase(Get.find<AuthRepository>()),
        getWallet: GetWalletUseCase(Get.find<WalletRepository>()),
        listCoinPackages: ListCoinPackagesUseCase(Get.find<WalletRepository>()),
        topUpWallet: TopUpWalletUseCase(Get.find<WalletRepository>()),
        eventsClient: Get.find<LiveEventsClient>(),
        apiClient: Get.find<ApiClient>(),
      ),
      permanent: true,
    );
  }
}

class LiveListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LiveListController>(
      () => LiveListController(
        listLiveStreams: ListLiveStreamsUseCase(
          Get.find<LiveStreamRepository>(),
        ),
        globalLeaderboard: GlobalLeaderboardUseCase(Get.find<GiftRepository>()),
        eventsClient: Get.find<LiveEventsClient>(),
      ),
      fenix: true,
    );
  }
}

/// Built per room. The arguments decide which side of the room this is:
/// `{'mode': 'host', 'title': ...}` opens a broadcast, `{'streamId': ...}`
/// joins one.
class LiveRoomBinding extends Bindings {
  @override
  void dependencies() {
    final Map<String, dynamic> args =
        (Get.arguments as Map<String, dynamic>?) ?? <String, dynamic>{};
    final bool isHost = args['mode'] == 'host';

    Get.put<LiveRoomController>(
      LiveRoomController(
        mode: isHost ? LiveRoomMode.host : LiveRoomMode.audience,
        streamId: args['streamId'] as String?,
        initialTitle: args['title'] as String?,
        startBroadcast: StartBroadcastUseCase(Get.find<LiveStreamRepository>()),
        joinStream: JoinStreamUseCase(Get.find<LiveStreamRepository>()),
        endStream: EndStreamUseCase(Get.find<LiveStreamRepository>()),
        heartbeat: HeartbeatUseCase(Get.find<LiveStreamRepository>()),
        sendReactionUseCase: SendReactionUseCase(
          Get.find<LiveStreamRepository>(),
        ),
        sendChatMessage: SendChatMessageUseCase(Get.find<ChatRepository>()),
        loadGiftCatalogue: LoadGiftCatalogueUseCase(Get.find<GiftRepository>()),
        sendGiftUseCase: SendGiftUseCase(Get.find<GiftRepository>()),
        streamLeaderboard: StreamLeaderboardUseCase(Get.find<GiftRepository>()),
        mediaEngine: Get.find<LiveMediaEngine>(),
        eventsClient: Get.find<LiveEventsClient>(),
        session: Get.find<SessionController>(),
        requestCameraPermission: RequestCameraPermissionUseCase(
          Get.find<PermissionRepository>(),
        ),
        requestMicrophonePermission: RequestMicrophonePermissionUseCase(
          Get.find<PermissionRepository>(),
        ),
        openSettings: OpenApplicationSettingsUseCase(
          Get.find<PermissionRepository>(),
        ),
      ),
    );
  }
}
