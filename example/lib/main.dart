import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
// Ensure this points to the file we created in the previous step
import 'package:video_thumbnail_slider/video_thumbnail_slider.dart';

class SeltectThumbnailPage extends StatefulWidget {
  const SeltectThumbnailPage({required this.media, Key? key}) : super(key: key);
  final File media;

  @override
  State<SeltectThumbnailPage> createState() => _SeltectThumbnailPageState();
}

class _SeltectThumbnailPageState extends State<SeltectThumbnailPage> {
  // Media Kit objects
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    // Initialize Media Kit player
    player = Player();
    controller = VideoController(player);

    // Open the media file
    player.open(Media(widget.media.path));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark theme background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          CupertinoButton(
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                // Handle save logic
              })
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Video Preview Area
            Expanded(
              child: Center(
                child: FittedVideoPlayer(
                  controller: controller,
                  height: 400,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Thumbnail Slider
            VideoThumbnailSlider(
              controller: controller,
              splitImage: 11,
              width: MediaQuery.of(context).size.width - 32,
              height: 60, // Slightly taller for better touch target
              backgroundColor: const Color(0xFF2C2C2C),
              indicatorColor: Colors.blueAccent, // Matches the Save button

              // Custom builder for the individual thumbnails in the background
              frameBuilder: (imgData) => Container(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.black.withOpacity(0.1), width: 0.5)),
                child: Image.memory(
                  imgData,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),

              // Custom builder for the "Scrubber" (Current selection)
              customCurrentFrameBuilder: (ctrl) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Video(
                    controller: ctrl,
                    fit: BoxFit.cover,
                    controls: NoVideoControls,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class FittedVideoPlayer extends StatelessWidget {
  const FittedVideoPlayer(
      {required this.controller, this.height = 300, Key? key})
      : super(key: key);

  final VideoController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Media Kit's Video widget handles aspect ratio nicely with BoxFit.contain
    return SizedBox(
      height: height,
      width: MediaQuery.of(context).size.width,
      child: VideoPlayerView(
        videoController: controller,
      ),
    );
  }
}

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView(
      {required this.videoController, this.autoPlay = true, Key? key})
      : super(key: key);

  final VideoController videoController;
  final bool autoPlay;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      widget.videoController.player.play();
    }
  }

  void onVideoTap() {
    final player = widget.videoController.player;
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onVideoTap,
      child: Video(
        controller: widget.videoController,
        fit: BoxFit
            .contain, // Ensures the video fits within the bounds without cropping
        controls: NoVideoControls, // Clean view without default overlay
      ),
    );
  }
}
