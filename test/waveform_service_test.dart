import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_waveform/just_waveform.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/waveform_service.dart';

void main() {
  late Directory temporaryDirectory;
  late File audioFile;
  late Song song;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'auralis_waveform_test_',
    );
    audioFile = File('${temporaryDirectory.path}/track.mp3');
    await audioFile.writeAsBytes([1, 2, 3, 4]);
    song = Song(
      id: 'track',
      title: 'Track',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      path: audioFile.path,
      format: 'mp3',
      mimeType: 'audio/mpeg',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('reuses a persisted waveform across service instances', () async {
    var extractions = 0;
    final first = WaveformService(
      directoryProvider: () async => temporaryDirectory,
      extractor: (audio, output) async {
        extractions++;
        return _writeWaveform(output);
      },
    );

    expect(await first.load(song), isNotNull);
    expect(extractions, 1);
    final persisted = await Directory('${temporaryDirectory.path}/waveforms')
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .single;
    expect(await JustWaveform.parse(persisted), isNotNull);

    final second = WaveformService(
      directoryProvider: () async => temporaryDirectory,
      extractor: (audio, output) async {
        extractions++;
        return _writeWaveform(output);
      },
    );
    expect(await second.load(song), isNotNull);
    expect(extractions, 1);
  });

  test('regenerates waveform when the source file changes', () async {
    var extractions = 0;
    Future<Waveform?> extractor(File audio, File output) async {
      extractions++;
      return _writeWaveform(output);
    }

    final first = WaveformService(
      directoryProvider: () async => temporaryDirectory,
      extractor: extractor,
    );
    await first.load(song);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await audioFile.writeAsBytes([1, 2, 3, 4, 5, 6]);

    final second = WaveformService(
      directoryProvider: () async => temporaryDirectory,
      extractor: extractor,
    );
    await second.load(song);
    expect(extractions, 2);

    final cachedFiles = await Directory('${temporaryDirectory.path}/waveforms')
        .list()
        .where((entity) => entity.path.endsWith('.wave'))
        .toList();
    expect(cachedFiles, hasLength(1));
  });
}

Future<Waveform> _writeWaveform(File output) async {
  const length = 4;
  final bytes = ByteData(100)
    ..setUint32(0, 1, Endian.host)
    ..setUint32(4, 0, Endian.host)
    ..setUint32(8, 44100, Endian.host)
    ..setUint32(12, 2205, Endian.host)
    ..setUint32(16, length, Endian.host);
  for (var index = 0; index < length * 2; index++) {
    bytes.setInt16(20 + index * 2, index.isEven ? -12000 : 12000, Endian.host);
  }
  await output.parent.create(recursive: true);
  await output.writeAsBytes(bytes.buffer.asUint8List());
  return Waveform(
    version: 1,
    flags: 0,
    sampleRate: 44100,
    samplesPerPixel: 2205,
    length: length,
    data: List<int>.generate(
      length * 2,
      (index) => index.isEven ? -12000 : 12000,
    ),
  );
}
