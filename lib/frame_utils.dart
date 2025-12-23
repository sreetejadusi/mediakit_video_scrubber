import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FrameUtils {
  /// Generates a single thumbnail at the specified position.
  Future<Uint8List?> getThumbnail(
    String videoPath, {
    Duration position = Duration.zero,
    int quality = 75,
  }) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: quality, // Lower default quality slightly for performance
        timeMs: position.inMilliseconds,
      );
      return uint8list;
    } catch (e, s) {
      debugPrint('Error generating thumbnail: $e');
      debugPrintStack(stackTrace: s);
      return null;
    }
  }

  /// Generates a list of thumbnails using an isolate to avoid blocking the UI.
  Future<List<Uint8List>> getListThumbnailIsolate({
    required String videoPath,
    required Duration duration,
    required int split,
  }) async {
    final receivePort = ReceivePort();
    final rootToken = RootIsolateToken.instance;
    
    if (rootToken == null) {
      throw Exception('RootIsolateToken is null. Cannot spawn isolate.');
    }

    final isolateData = {
      'videoPath': videoPath,
      'duration': duration,
      'split': split,
      'sendPort': receivePort.sendPort,
      'token': rootToken,
    };

    await Isolate.spawn(_generateThumbnailsEntryPoint, isolateData);

    // Wait for the result from the isolate
    final List<Uint8List> listThumbnail = await receivePort.first;
    receivePort.close();

    return listThumbnail;
  }

  /// The entry point for the isolate.
  static Future<void> _generateThumbnailsEntryPoint(Map<String, dynamic> data) async {
    final rootToken = data['token'] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    final videoPath = data['videoPath'] as String;
    final duration = data['duration'] as Duration;
    final split = data['split'] as int;
    final sendPort = data['sendPort'] as SendPort;

    // Calculate time points
    final jumpStep = (duration.inMilliseconds / split).ceil();
    final List<Duration> timePoints = [];
    for (int ms = 0; ms < duration.inMilliseconds; ms += jumpStep) {
      timePoints.add(Duration(milliseconds: ms));
    }

    final List<Uint8List> thumbnails = [];
    final utils = FrameUtils();

    for (var timePoint in timePoints) {
      // Limit to split count to prevent overflow if duration/step is slightly off
      if (thumbnails.length >= split) break; 
      
      final thumbnail = await utils.getThumbnail(videoPath, position: timePoint);
      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }

    sendPort.send(thumbnails);
  }
}