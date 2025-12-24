import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FrameUtils {
  /// Generates a single thumbnail.
  Future<Uint8List?> getThumbnail(
    String videoPath, {
    Duration position = Duration.zero,
    int quality = 50, // Reduced default quality for speed
    int maxHeight =
        0, // 0 = original. Set this to match widget height for performance.
  }) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: quality,
        maxHeight: maxHeight,
        timeMs: position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Spawns an isolate to generate thumbnails and streams them back.
  /// Returns a ReceivePort that emits [List<Uint8List>] (cumulative) or individual [Uint8List].
  Stream<Uint8List> generateThumbnailsStream({
    required String videoPath,
    required Duration duration,
    required int split,
    int quality = 50,
    int maxHeight = 0,
  }) {
    final receivePort = ReceivePort();
    final rootToken = RootIsolateToken.instance;

    if (rootToken == null) {
      throw Exception('RootIsolateToken is null.');
    }

    final isolateData = {
      'videoPath': videoPath,
      'duration': duration,
      'split': split,
      'quality': quality,
      'maxHeight': maxHeight,
      'sendPort': receivePort.sendPort,
      'token': rootToken,
    };

    Isolate.spawn(_generateThumbnailsEntryPoint, isolateData);

    // Transform the receive port into a typed stream and handle cleanup
    final controller = StreamController<Uint8List>();

    final sub = receivePort.listen((message) {
      if (message is Uint8List) {
        controller.add(message);
      } else if (message == 'DONE') {
        controller.close();
        receivePort.close();
      }
    });

    controller.onCancel = () {
      sub.cancel();
      receivePort.close();
      // ideally we would kill the isolate here too, but for simple request/reply
      // letting it finish or GC is usually acceptable for this scope.
    };

    return controller.stream;
  }

  static Future<void> _generateThumbnailsEntryPoint(
      Map<String, dynamic> data) async {
    final rootToken = data['token'] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    final videoPath = data['videoPath'] as String;
    final duration = data['duration'] as Duration;
    final split = data['split'] as int;
    final quality = data['quality'] as int;
    final maxHeight = data['maxHeight'] as int;
    final sendPort = data['sendPort'] as SendPort;

    final jumpStep = (duration.inMilliseconds / split).ceil();
    final utils = FrameUtils();

    for (int i = 0; i < split; i++) {
      final currentMs = i * jumpStep;
      // Ensure we don't go past end
      if (currentMs > duration.inMilliseconds) break;

      final bytes = await utils.getThumbnail(
        videoPath,
        position: Duration(milliseconds: currentMs),
        quality: quality,
        maxHeight: maxHeight,
      );

      if (bytes != null) {
        sendPort.send(bytes);
      }
    }

    sendPort.send('DONE');
  }
}
