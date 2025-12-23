library video_thumbnail_slider;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart'; // Import media_kit
import 'package:media_kit_video/media_kit_video.dart'; // Import media_kit_video
import 'package:video_thumbnail_slider/frame_utils.dart'; // Adjust path if necessary

class VideoThumbnailSlider extends StatefulWidget {
  /// The controller for the media_kit video player.
  final VideoController controller;

  /// The height of the slider track (thumbnails).
  final double height;

  /// The width of the slider.
  final double width;

  /// The number of split images in the thumbnail slider.
  final int splitImage;

  /// The background color of the slider container.
  final Color backgroundColor;

  /// Color of the current position indicator border.
  final Color indicatorColor;

  /// Custom builder for the floating current frame preview.
  final Widget Function(VideoController controller)? customCurrentFrameBuilder;

  /// Builder for individual thumbnails in the background.
  final Widget Function(Uint8List imageData)? frameBuilder;

  const VideoThumbnailSlider({
    Key? key,
    required this.controller,
    this.height = 60,
    this.width = 350,
    this.splitImage = 7,
    this.customCurrentFrameBuilder,
    this.frameBuilder,
    this.backgroundColor = const Color(0xFF121212),
    this.indicatorColor = Colors.white,
  }) : super(key: key);

  @override
  State<VideoThumbnailSlider> createState() => _VideoThumbnailSliderState();
}

class _VideoThumbnailSliderState extends State<VideoThumbnailSlider> {
  double _slidePosition = 0.0;
  late final Player _player;
  late StreamSubscription<Duration> _positionSubscription;

  @override
  void initState() {
    super.initState();
    _player = widget.controller.player;

    // Listen to position updates from media_kit
    _positionSubscription = _player.stream.position.listen((position) {
      final totalDuration = _player.state.duration;
      if (totalDuration != Duration.zero) {
        final newPos = position.inMilliseconds / totalDuration.inMilliseconds;
        setState(() {
          _slidePosition = newPos.clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    super.dispose();
  }

  /// Handles user dragging the slider.
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slidePosition += details.delta.dx / widget.width;
      _slidePosition = _slidePosition.clamp(0.0, 1.0);
    });

    final totalSeconds = _player.state.duration.inSeconds;
    // Debounce or seek directly? Direct seek is usually fine with media_kit.
    _player.seek(Duration(seconds: (totalSeconds * _slidePosition).ceil()));
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the width of a single thumbnail segment
    final thumbWidth = widget.width / widget.splitImage;

    return SizedBox(
      width: widget.width,
      height: widget.height + 20, // Extra height for the border/shadow effects
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Background Thumbnails
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ThumbnailStrip(
                controller: widget.controller,
                splitThumb: widget.splitImage,
                frameBuilder: widget.frameBuilder,
              ),
            ),
          ),

          // The Scrubber (Current Frame Indicator)
          Positioned(
            left: (widget.width - thumbWidth) * _slidePosition,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              child: Container(
                width: thumbWidth,
                height: widget.height,
                decoration: BoxDecoration(
                  border: Border.all(color: widget.indicatorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: widget.customCurrentFrameBuilder?.call(
                        widget.controller,
                      ) ??
                      Video(
                        controller: widget.controller,
                        fit: BoxFit.cover,
                        controls:
                            NoVideoControls, // Hide default controls in the slider
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailStrip extends StatefulWidget {
  final VideoController controller;
  final int splitThumb;
  final Widget Function(Uint8List)? frameBuilder;

  const _ThumbnailStrip({
    required this.controller,
    required this.splitThumb,
    this.frameBuilder,
    Key? key,
  }) : super(key: key);

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  List<Uint8List> _thumbnails = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnails();
  }

  Future<void> _generateThumbnails() async {
    final player = widget.controller.player;

    // Ensure duration is available. If 0, wait a bit or listen to stream.
    if (player.state.duration == Duration.zero) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Extract path from media_kit player state
    String? videoPath;
    final playlist = player.state.playlist;
    if (playlist.medias.isNotEmpty) {
      final media = playlist.medias[playlist.index];
      videoPath = media.uri;
    }

    if (videoPath == null) {
      if (mounted) setState(() => _isLoading = false);
      throw Exception("Video path is null.");
    }


    if (videoPath.startsWith('file://')) {
      try {
        videoPath = Uri.parse(videoPath).toFilePath();
      } catch (e) {
        debugPrint("Error parsing file URI: $e");
      }
    }

    try {
      final results = await FrameUtils().getListThumbnailIsolate(
        videoPath: videoPath!,
        duration: player.state.duration,
        split: widget.splitThumb,
      );

      if (mounted) {
        setState(() {
          _thumbnails = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error generating thumbnails: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (_thumbnails.isEmpty) {
      return Container(color: Colors.grey[900]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _thumbnails.map((imgData) {
        return Expanded(
          child: widget.frameBuilder?.call(imgData) ??
              Image.memory(imgData, fit: BoxFit.cover, gaplessPlayback: true),
        );
      }).toList(),
    );
  }
}
