import '../entities/short_video_entity.dart';
import '../repositories/short_video_repository.dart';

class LoadVideoFeedUseCase {
  const LoadVideoFeedUseCase(this._repository);
  final ShortVideoRepository _repository;
  Future<List<ShortVideoEntity>> call() => _repository.feed();
}

class SetVideoLikedUseCase {
  const SetVideoLikedUseCase(this._repository);
  final ShortVideoRepository _repository;
  Future<ShortVideoEntity> call(String id, bool active) =>
      _repository.setLiked(id, active);
}

class SetVideoBookmarkedUseCase {
  const SetVideoBookmarkedUseCase(this._repository);
  final ShortVideoRepository _repository;
  Future<ShortVideoEntity> call(String id, bool active) =>
      _repository.setBookmarked(id, active);
}
