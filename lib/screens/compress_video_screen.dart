import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

class CompressVideoScreen extends StatefulWidget {
  const CompressVideoScreen({super.key});

  @override
  State<CompressVideoScreen> createState() => _CompressVideoScreenState();
}

class _CompressVideoScreenState extends State<CompressVideoScreen> {
  static const MethodChannel _platform = MethodChannel(
    'com.abdsukapdf.tools/videoCompression',
  );

  int _resolutionIndex = 1;
  double _durationSeconds = 30;
  double _fps = 30;
  double _quality = 58;
  double _gopSize = 12;
  double _motionLevel = 62;
  bool _isCompressing = false;
  PlatformFile? _selectedVideo;
  _SavedVideoResult? _lastSavedVideo;

  static const List<_ResolutionPreset> _resolutions = [
    _ResolutionPreset('480p', 854, 480),
    _ResolutionPreset('720p', 1280, 720),
    _ResolutionPreset('1080p', 1920, 1080),
    _ResolutionPreset('4K', 3840, 2160),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final result = _calculateResult();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050506) : const Color(0xFFF4F5F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 24, isWide ? 32 : 20, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  isDark: isDark,
                  onPickVideo: _pickVideo,
                  selectedVideoName: _selectedVideo?.name,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 20, isWide ? 32 : 20, 24),
              sliver: SliverToBoxAdapter(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _ControlsPanel(
                              isDark: isDark,
                              resolutionIndex: _resolutionIndex,
                              durationSeconds: _durationSeconds,
                              fps: _fps,
                              quality: _quality,
                              gopSize: _gopSize,
                              motionLevel: _motionLevel,
                              resolutions: _resolutions,
                              onResolutionChanged: (value) => setState(() => _resolutionIndex = value),
                              onDurationChanged: (value) => setState(() => _durationSeconds = value),
                              onFpsChanged: (value) => setState(() => _fps = value),
                              onQualityChanged: (value) => setState(() => _quality = value),
                              onGopChanged: (value) => setState(() => _gopSize = value),
                              onMotionChanged: (value) => setState(() => _motionLevel = value),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: _ResultPanel(
                              isDark: isDark,
                              result: result,
                              hasSelectedVideo: _selectedVideo?.path != null,
                              isCompressing: _isCompressing,
                              lastSavedVideo: _lastSavedVideo,
                              onSave: _compressAndSaveToGallery,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _ControlsPanel(
                            isDark: isDark,
                            resolutionIndex: _resolutionIndex,
                            durationSeconds: _durationSeconds,
                            fps: _fps,
                            quality: _quality,
                            gopSize: _gopSize,
                            motionLevel: _motionLevel,
                            resolutions: _resolutions,
                            onResolutionChanged: (value) => setState(() => _resolutionIndex = value),
                            onDurationChanged: (value) => setState(() => _durationSeconds = value),
                            onFpsChanged: (value) => setState(() => _fps = value),
                            onQualityChanged: (value) => setState(() => _quality = value),
                            onGopChanged: (value) => setState(() => _gopSize = value),
                            onMotionChanged: (value) => setState(() => _motionLevel = value),
                          ),
                          const SizedBox(height: 16),
                          _ResultPanel(
                            isDark: isDark,
                            result: result,
                            hasSelectedVideo: _selectedVideo?.path != null,
                            isCompressing: _isCompressing,
                            lastSavedVideo: _lastSavedVideo,
                            onSave: _compressAndSaveToGallery,
                          ),
                        ],
                      ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 0, isWide ? 32 : 20, 24),
              sliver: SliverToBoxAdapter(
                child: _MpegPipeline(isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (!mounted || result == null || result.files.isEmpty) return;

    setState(() {
      _selectedVideo = result.files.first;
      _lastSavedVideo = null;
      if (_selectedVideo?.size != null && _selectedVideo!.size > 0) {
        final estimatedSeconds = (_selectedVideo!.size / (1024 * 1024)).clamp(5, 180).toDouble();
        _durationSeconds = estimatedSeconds;
      }
    });
  }

  Future<void> _compressAndSaveToGallery() async {
    final video = _selectedVideo;
    final path = video?.path;
    if (path == null || path.isEmpty) {
      _showMessage('Pick a video first.');
      return;
    }

    setState(() {
      _isCompressing = true;
      _lastSavedVideo = null;
    });

    try {
      final preset = _resolutions[_resolutionIndex];
      final response = await _platform.invokeMapMethod<String, dynamic>(
        'compressVideoToGallery',
        {
          'inputPath': path,
          'width': preset.width,
          'height': preset.height,
          'fps': _fps.round(),
          'quality': _quality.round(),
          'durationSeconds': _durationSeconds.round(),
          'gopSize': _gopSize.round(),
        },
      );

      if (!mounted) return;
      setState(() {
        _lastSavedVideo = _SavedVideoResult.fromMap(response ?? {});
      });
      _showMessage('Compressed video saved to Gallery.');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showMessage(e.message ?? 'Video compression failed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Video compression failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _CompressionResult _calculateResult() {
    final preset = _resolutions[_resolutionIndex];
    final frames = (_durationSeconds * _fps).round();
    final rawBytes = preset.width * preset.height * 3 * frames;
    final iFrames = math.max(1, (frames / _gopSize).ceil());
    final pFrames = math.max(0, (frames - iFrames) * 0.34).round();
    final bFrames = math.max(0, frames - iFrames - pFrames);

    final qualityFactor = (101 - _quality) / 100;
    final motionFactor = 1 - (_motionLevel / 180);
    final gopFactor = (_gopSize / 12).clamp(0.5, 2.0);
    final compressionRatio = (14 + (qualityFactor * 22) + (motionFactor * 10) + (gopFactor * 6)).clamp(8, 52);
    final compressedBytes = rawBytes / compressionRatio;

    return _CompressionResult(
      resolution: preset,
      frames: frames,
      iFrames: iFrames,
      pFrames: pFrames,
      bFrames: bFrames,
      rawBytes: rawBytes.toDouble(),
      compressedBytes: compressedBytes,
      compressionRatio: compressionRatio.toDouble(),
      bitrateMbps: (compressedBytes * 8) / _durationSeconds / 1000000,
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPickVideo;
  final String? selectedVideoName;

  const _Header({
    required this.isDark,
    required this.onPickVideo,
    required this.selectedVideoName,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111113);
    final muted = isDark ? const Color(0xFF9B9CA3) : const Color(0xFF6F727B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF375F).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.movie_filter_rounded, color: Color(0xFFFF375F), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'MPEG Video Compression',
                style: TextStyle(fontSize: 28, height: 1.05, fontWeight: FontWeight.w900, color: textColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Simulate how MPEG reduces video size using frame prediction, DCT, quantization, and entropy coding.',
          style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600, color: muted),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPickVideo,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF17181C) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _softShadow(isDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_file_rounded, color: AppConfig.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedVideoName ?? 'Pick a video sample',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
                    ),
                  ),
                  const Icon(Icons.add_rounded, color: AppConfig.primaryColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final bool isDark;
  final int resolutionIndex;
  final double durationSeconds;
  final double fps;
  final double quality;
  final double gopSize;
  final double motionLevel;
  final List<_ResolutionPreset> resolutions;
  final ValueChanged<int> onResolutionChanged;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<double> onFpsChanged;
  final ValueChanged<double> onQualityChanged;
  final ValueChanged<double> onGopChanged;
  final ValueChanged<double> onMotionChanged;

  const _ControlsPanel({
    required this.isDark,
    required this.resolutionIndex,
    required this.durationSeconds,
    required this.fps,
    required this.quality,
    required this.gopSize,
    required this.motionLevel,
    required this.resolutions,
    required this.onResolutionChanged,
    required this.onDurationChanged,
    required this.onFpsChanged,
    required this.onQualityChanged,
    required this.onGopChanged,
    required this.onMotionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(title: 'Compression settings', isDark: isDark),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(resolutions.length, (index) {
              final selected = index == resolutionIndex;
              return ChoiceChip(
                selected: selected,
                label: Text(resolutions[index].label),
                onSelected: (_) => onResolutionChanged(index),
                showCheckmark: false,
                selectedColor: AppConfig.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF111113)),
                  fontWeight: FontWeight.w800,
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          _SliderRow(
            isDark: isDark,
            label: 'Duration',
            valueLabel: '${durationSeconds.round()}s',
            value: durationSeconds,
            min: 5,
            max: 180,
            divisions: 35,
            onChanged: onDurationChanged,
          ),
          _SliderRow(
            isDark: isDark,
            label: 'Frame rate',
            valueLabel: '${fps.round()} fps',
            value: fps,
            min: 12,
            max: 60,
            divisions: 16,
            onChanged: onFpsChanged,
          ),
          _SliderRow(
            isDark: isDark,
            label: 'Quantization',
            valueLabel: quality < 35 ? 'High compression' : quality > 72 ? 'High quality' : 'Balanced',
            value: quality,
            min: 10,
            max: 90,
            divisions: 16,
            onChanged: onQualityChanged,
          ),
          _SliderRow(
            isDark: isDark,
            label: 'GOP size',
            valueLabel: '${gopSize.round()} frames',
            value: gopSize,
            min: 6,
            max: 30,
            divisions: 12,
            onChanged: onGopChanged,
          ),
          _SliderRow(
            isDark: isDark,
            label: 'Motion similarity',
            valueLabel: '${motionLevel.round()}%',
            value: motionLevel,
            min: 10,
            max: 95,
            divisions: 17,
            onChanged: onMotionChanged,
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final bool isDark;
  final _CompressionResult result;
  final bool hasSelectedVideo;
  final bool isCompressing;
  final _SavedVideoResult? lastSavedVideo;
  final VoidCallback onSave;

  const _ResultPanel({
    required this.isDark,
    required this.result,
    required this.hasSelectedVideo,
    required this.isCompressing,
    required this.lastSavedVideo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(title: 'Estimated output', isDark: isDark),
          const SizedBox(height: 16),
          _MetricGrid(isDark: isDark, result: result),
          const SizedBox(height: 18),
          _FramePattern(isDark: isDark, result: result),
          const SizedBox(height: 18),
          _SaveButton(
            isDark: isDark,
            enabled: hasSelectedVideo && !isCompressing,
            isLoading: isCompressing,
            onTap: onSave,
          ),
          if (lastSavedVideo != null) ...[
            const SizedBox(height: 12),
            _SavedResultCard(isDark: isDark, result: lastSavedVideo!),
          ],
          const SizedBox(height: 18),
          _InfoStrip(
            isDark: isDark,
            text:
                'Saved compression exports an MP4/H.264 video to Movies/ABdCompressTools in Gallery.',
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isDark;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _SaveButton({
    required this.isDark,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: enabled
                ? AppConfig.primaryColor
                : (isDark ? const Color(0xFF24262D) : const Color(0xFFE5E7EC)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.save_alt_rounded,
                  color: enabled
                      ? Colors.white
                      : (isDark ? const Color(0xFF8E9099) : const Color(0xFF747782)),
                ),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Compressing...' : 'Compress & Save to Gallery',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: enabled || isLoading
                      ? Colors.white
                      : (isDark ? const Color(0xFF8E9099) : const Color(0xFF747782)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedResultCard extends StatelessWidget {
  final bool isDark;
  final _SavedVideoResult result;

  const _SavedResultCard({required this.isDark, required this.result});

  @override
  Widget build(BuildContext context) {
    final ratio = result.outputBytes == 0
        ? 0.0
        : result.inputBytes / result.outputBytes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111113),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatBytes(result.inputBytes.toDouble())} -> ${_formatBytes(result.outputBytes.toDouble())}   ${ratio.toStringAsFixed(1)}:1',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFC7F1D1) : const Color(0xFF246B35),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final bool isDark;
  final _CompressionResult result;

  const _MetricGrid({required this.isDark, required this.result});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Raw size', _formatBytes(result.rawBytes)),
      ('MPEG size', _formatBytes(result.compressedBytes)),
      ('Ratio', '${result.compressionRatio.toStringAsFixed(1)}:1'),
      ('Bitrate', '${result.bitrateMbps.toStringAsFixed(2)} Mbps'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222329) : const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                items[index].$1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF9B9CA3) : const Color(0xFF73757E),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  items[index].$2,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111113),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FramePattern extends StatelessWidget {
  final bool isDark;
  final _CompressionResult result;

  const _FramePattern({required this.isDark, required this.result});

  @override
  Widget build(BuildContext context) {
    final frames = ['I', 'B', 'B', 'P', 'B', 'B', 'P', 'B', 'B', 'P', 'B', 'B'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GOP frame pattern',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111113),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: frames.map((frame) {
            final color = switch (frame) {
              'I' => const Color(0xFFFF375F),
              'P' => const Color(0xFF0A84FF),
              _ => const Color(0xFF34C759),
            };
            return Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                frame,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          '${result.frames} frames: ${result.iFrames} I, ${result.pFrames} P, ${result.bFrames} B',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF9B9CA3) : const Color(0xFF73757E),
          ),
        ),
      ],
    );
  }
}

class _MpegPipeline extends StatelessWidget {
  final bool isDark;

  const _MpegPipeline({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PipelineStep('1', 'Frame prediction', 'Build I, P, and B frames to avoid storing repeated images.'),
      _PipelineStep('2', 'DCT transform', 'Convert pixel blocks into frequency coefficients.'),
      _PipelineStep('3', 'Quantization', 'Reduce less visible high-frequency detail.'),
      _PipelineStep('4', 'Entropy coding', 'Pack repeated symbols into fewer bits.'),
    ];

    return _Panel(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(title: 'MPEG compression pipeline', isDark: isDark),
          const SizedBox(height: 14),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      step.number,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111113),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF9B9CA3) : const Color(0xFF73757E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.isDark,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111113),
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF9B9CA3) : const Color(0xFF73757E),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppConfig.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _Panel({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17181C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow(isDark),
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _PanelTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF111113),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final bool isDark;
  final String text;

  const _InfoStrip({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFDCE9E6) : const Color(0xFF24524B),
        ),
      ),
    );
  }
}

class _ResolutionPreset {
  final String label;
  final int width;
  final int height;

  const _ResolutionPreset(this.label, this.width, this.height);
}

class _CompressionResult {
  final _ResolutionPreset resolution;
  final int frames;
  final int iFrames;
  final int pFrames;
  final int bFrames;
  final double rawBytes;
  final double compressedBytes;
  final double compressionRatio;
  final double bitrateMbps;

  const _CompressionResult({
    required this.resolution,
    required this.frames,
    required this.iFrames,
    required this.pFrames,
    required this.bFrames,
    required this.rawBytes,
    required this.compressedBytes,
    required this.compressionRatio,
    required this.bitrateMbps,
  });
}

class _SavedVideoResult {
  final String displayName;
  final String uri;
  final int inputBytes;
  final int outputBytes;

  const _SavedVideoResult({
    required this.displayName,
    required this.uri,
    required this.inputBytes,
    required this.outputBytes,
  });

  factory _SavedVideoResult.fromMap(Map<String, dynamic> map) {
    return _SavedVideoResult(
      displayName: map['displayName']?.toString() ?? 'Compressed video.mp4',
      uri: map['uri']?.toString() ?? '',
      inputBytes: (map['inputBytes'] as num?)?.toInt() ?? 0,
      outputBytes: (map['outputBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class _PipelineStep {
  final String number;
  final String title;
  final String description;

  const _PipelineStep(this.number, this.title, this.description);
}

String _formatBytes(double bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
}

List<BoxShadow> _softShadow(bool isDark) {
  if (isDark) return const [];
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}
