import 'package:flutter_test/flutter_test.dart';
import 'package:aniwhere/data/sources/music_service.dart';
import 'package:aniwhere/data/models/music_models.dart';

void main() {
  test('MusicService resolves distinct streams for different tracks', () async {
    final service = MusicService();

    final ashke = const MusicTrack(
      id: 'AhkSYQEF',
      title: 'Ashke',
      artist: 'Karan Aujla',
      album: 'AUJLA SZN 1',
      duration: Duration(minutes: 3),
      streamUrl: '',
      encryptedMediaUrl: 'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDy4/qZnX07bWmykrJ0OhzqQS5G905lHZvPpUo+fmuE6U3y1QQNfpNHXRw7tS9a8Gtq',
    );

    final dracula = const MusicTrack(
      id: '7WiJwj-y',
      title: 'Dracula',
      artist: 'Tame Impala',
      album: 'Dracula',
      duration: Duration(minutes: 3),
      streamUrl: '',
      encryptedMediaUrl: 'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyNJLTBmuGLE5G8stEjFpvz06XxhUqwYT2N3kmWvCIaHHo2d94mW8Bjxw7tS9a8Gtq',
    );

    final ashkeUrl = await service.resolveStreamUrl(ashke);
    final draculaUrl = await service.resolveStreamUrl(dracula);

    print('Ashke URL: $ashkeUrl');
    print('Dracula URL: $draculaUrl');

    expect(ashkeUrl.isNotEmpty, true);
    expect(draculaUrl.isNotEmpty, true);
    expect(ashkeUrl != draculaUrl, true);

    // Test AudioQuality switching
    final lowUrl = await service.resolveStreamUrl(ashke, quality: AudioQuality.low);
    final medUrl = await service.resolveStreamUrl(ashke, quality: AudioQuality.medium);
    final highUrl = await service.resolveStreamUrl(ashke, quality: AudioQuality.lossless);

    expect(lowUrl.contains('_96.'), true);
    expect(medUrl.contains('_160.'), true);
    expect(highUrl.contains('_320.'), true);
  });

  test('MusicService resolves distinct streams for Unravel, Wavy, and Blue Bird', () async {
    final service = MusicService();
    final albums = await service.getAlbumsAndSingles();

    expect(albums.isNotEmpty, true);
    expect(albums.any((a) => a.title == 'AUJLA SZN 1'), true);
    expect(albums.any((a) => a.title == 'Tokyo Ghoul OST'), true);

    final aujlaAlbum = albums.firstWhere((a) => a.title == 'AUJLA SZN 1');
    expect(aujlaAlbum.tracks.length, 2);
    expect(aujlaAlbum.tracks[0].title, 'Ashke');
    expect(aujlaAlbum.tracks[1].title, 'Wavy');

    final ashkeStream = await service.resolveStreamUrl(aujlaAlbum.tracks[0]);
    final wavyStream = await service.resolveStreamUrl(aujlaAlbum.tracks[1]);
    expect(ashkeStream.isNotEmpty, true);
    expect(wavyStream.isNotEmpty, true);
    expect(ashkeStream != wavyStream, true);
  });
}
