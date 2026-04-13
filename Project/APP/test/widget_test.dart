import 'package:flutter_test/flutter_test.dart';
import 'package:sport_music/audio_service.dart';

void main() {
  test('sport mapping stays available', () {
    expect(SportType.fromRawValue('walking'), SportType.walking);
    expect(SportType.fromRawValue('running'), SportType.running);
    expect(SportType.fromRawValue('resting'), SportType.resting);
    expect(SportType.fromRawValue('unknown'), isNull);
  });
}
