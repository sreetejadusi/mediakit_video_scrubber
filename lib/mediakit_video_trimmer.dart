library mediakit_video_trimmer;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mediakit_video_trimmer/frame_utils.dart';

class MediakitVideoTrimmer extends StatefulWidget {
  final VideoController controller;
  final double height;
  final double width;
  final int splitImage;
  final Color backgroundColor;
  final Color overlayColor; // Color of the dimmed area outside selection
  final Color handlerColor; // Color of the trim handles
  final Color scrubberColor; // Color of the current position indicator

  /// Callback when the start or end selection changes.
  /// Returns the start and end values as normalized doubles (0.0 to 1.0).
  final Function(double start, double end)? onRangeChanged;

  const MediakitVideoTrimmer({
    Key? key,
    required this.controller,
    this.height = 60,
    this.width = 350,
    this.splitImage = 10, // Increased default for smoother strip
    this.backgroundColor = const Color(0xFF121212),
    this.overlayColor = const Color(0x99000000),
    this.handlerColor = Colors.blueAccent,
    this.scrubberColor = Colors.white,
    this.onRangeChanged,
  }) : super(key: key);

  @override
  State<MediakitVideoTrimmer> createState() => _MediakitVideoTrimmerState();
}

class _MediakitVideoTrimmerState extends State<MediakitVideoTrimmer> {
  // Positions are normalized (0.0 to 1.0)
  double _startPos = 0.0;
  double _endPos = 1.0;
  double _currentPos = 0.0;

  late final Player _player;
  StreamSubscription? _posSub;

  // Cache the thumb width calculation
  double get _totalWidth => widget.width;
  double get _handlerWidth => 16.0; // Width of the touch target for handles

  @override
  void initState() {
    super.initState();
    _player = widget.controller.player;

    // Listen to playback to update the scrubber position
    _posSub = _player.stream.position.listen((position) {
      final total = _player.state.duration.inMilliseconds;
      if (total > 0) {
        final newPos = position.inMilliseconds / total;
        // Only update UI if we are not actively dragging (optional check could be added)
        if (mounted) {
          setState(() {
            _currentPos = newPos.clamp(0.0, 1.0);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  /// Seek video to a normalized position
  void _seekTo(double normalizedPos) {
    final total = _player.state.duration.inMilliseconds;
    if (total > 0) {
      final ms = (normalizedPos * total).round();
      _player.seek(Duration(milliseconds: ms));
    }
  }

  // --- Drag Handlers ---

  void _onDragStartHandle(DragUpdateDetails details) {
    setState(() {
      _startPos += details.delta.dx / _totalWidth;
      // Clamp: 0 <= start <= end
      _startPos = _startPos.clamp(0.0, _endPos - 0.05); // Keep min 5% gap
    });
    _seekTo(_startPos);
    widget.onRangeChanged?.call(_startPos, _endPos);
  }

  void _onDragEndHandle(DragUpdateDetails details) {
    setState(() {
      _endPos += details.delta.dx / _totalWidth;
      // Clamp: start <= end <= 1.0
      _endPos = _endPos.clamp(_startPos + 0.05, 1.0);
    });
    _seekTo(_endPos);
    widget.onRangeChanged?.call(_startPos, _endPos);
  }

  void _onDragScrubber(DragUpdateDetails details) {
    setState(() {
      _currentPos += details.delta.dx / _totalWidth;
      _currentPos = _currentPos.clamp(0.0, 1.0);
    });
    _seekTo(_currentPos);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height + 24, // Extra space for handle overhang
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Thumbnail Background
          _ThumbnailStrip(
            controller: widget.controller,
            splitThumb: widget.splitImage,
            width: widget.width,
            height: widget.height,
            backgroundColor: widget.backgroundColor,
          ),

          // 2. Dark Overlays (Trimming visualization)
          Positioned.fill(
            child: Row(
              children: [
                // Left dimmed area
                Container(
                  width: widget.width * _startPos,
                  height: widget.height,
                  color: widget.overlayColor,
                ),
                // Active Area (Transparent)
                Expanded(child: Container()),
                // Right dimmed area
                Container(
                  width: widget.width * (1.0 - _endPos),
                  height: widget.height,
                  color: widget.overlayColor,
                ),
              ],
            ),
          ),

          // 3. Borders for the selection area
          Positioned(
            left: widget.width * _startPos,
            width: widget.width * (_endPos - _startPos),
            height: widget.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: widget.handlerColor, width: 2),
                  bottom: BorderSide(color: widget.handlerColor, width: 2),
                ),
              ),
            ),
          ),

          // 4. Start Handle (Left)
          Positioned(
            left: (widget.width * _startPos) - (_handlerWidth / 2),
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragStartHandle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: _handlerWidth,
                height: widget.height + 10,
                decoration: BoxDecoration(
                  color: widget.handlerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_left,
                    size: 16, color: Colors.white),
              ),
            ),
          ),

          // 5. End Handle (Right)
          Positioned(
            left: (widget.width * _endPos) - (_handlerWidth / 2),
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragEndHandle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: _handlerWidth,
                height: widget.height + 10,
                decoration: BoxDecoration(
                  color: widget.handlerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.chevron_right,
                    size: 16, color: Colors.white),
              ),
            ),
          ),

          // 6. Current Scrubber (Floating Line)
          Positioned(
            left: (widget.width * _currentPos) - 2, // Center the 4px line
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragScrubber,
              child: Container(
                width: 4,
                height: widget.height + 16,
                decoration: BoxDecoration(
                  color: widget.scrubberColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 2)
                  ],
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
  final double width;
  final double height;
  final Color backgroundColor;

  const _ThumbnailStrip({
    required this.controller,
    required this.splitThumb,
    required this.width,
    required this.height,
    required this.backgroundColor,
  });

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  final List<Uint8List?> _thumbnails = [];
  StreamSubscription? _streamSub;

  @override
  void initState() {
    super.initState();
    // Initialize list with nulls placeholders
    _thumbnails.addAll(List.filled(widget.splitThumb, null));
    _startGeneration();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    final player = widget.controller.player;
    // Wait for duration to be known
    if (player.state.duration == Duration.zero) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Extract Path
    String? videoPath;
    final playlist = player.state.playlist;
    if (playlist.medias.isNotEmpty) {
      final media = playlist.medias[playlist.index];
      videoPath = media.uri;
    }

    if (videoPath == null) return;

    // Convert file URI if needed
    if (videoPath.startsWith('file://')) {
      try {
        videoPath = Uri.parse(videoPath).toFilePath();
      } catch (_) {}
    }

    // Start Streaming
    int index = 0;
    _streamSub = FrameUtils()
        .generateThumbnailsStream(
      videoPath: videoPath!,
      duration: player.state.duration,
      split: widget.splitThumb,
      // IMPORTANT: Set maxHeight to widget height to reduce memory usage & decode time
      maxHeight: widget.height.toInt(),
      quality: 40,
    )
        .listen((bytes) {
      if (mounted && index < _thumbnails.length) {
        setState(() {
          _thumbnails[index] = bytes;
        });
        index++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _thumbnails.map((bytes) {
            return Expanded(
              child: bytes == null
                  // Loading Placeholder
                  ? Container(
                      color: Colors.white10,
                      child: const Center(
                          child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1, color: Colors.white24))),
                    )
                  // The Thumbnail
                  : Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Optimization: Cache image in memory
                      cacheHeight: widget.height.toInt(),
                    ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
