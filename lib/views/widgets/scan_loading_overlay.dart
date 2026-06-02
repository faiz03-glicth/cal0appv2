// lib/views/widgets/scan_loading_overlay.dart
//
// Fast, energetic scan loading overlay.
// Animations tuned for speed — everything runs at 2–3× the previous pace.
//
// Visual elements:
//   • Spinning arc ring around the icon (continuous, 700ms/rev)
//   • Horizontal scan-line sweeping top→bottom inside the icon (800ms)
//   • Icon cross-fades on stage change (150ms)
//   • Progress bar with animated shimmer sweep (400ms fill + live shimmer)
//   • Stage pill dots with quick spring transitions
//   • Whole overlay fades in in 150ms

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cal0appv2/theme/app_theme.dart';
import 'package:cal0appv2/models/scan/scan_stage.dart';

class ScanLoadingOverlay extends StatefulWidget {
  final ScanStage stage;
  const ScanLoadingOverlay({super.key, required this.stage});

  @override
  State<ScanLoadingOverlay> createState() => _ScanLoadingOverlayState();
}

class _ScanLoadingOverlayState extends State<ScanLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _scanLineCtrl;
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  double _progressFrom = 0.0;

  static const _orderedStages = [
    ScanStage.preparingImage,
    ScanStage.enhancingQuality,
    ScanStage.extractingText,
    ScanStage.analyzingIngredients,
    ScanStage.generatingInsights,
  ];

  static IconData _iconFor(ScanStage s) {
    switch (s) {
      case ScanStage.preparingImage:
        return Icons.image_outlined;
      case ScanStage.enhancingQuality:
        return Icons.auto_fix_high;
      case ScanStage.extractingText:
        return Icons.document_scanner_outlined;
      case ScanStage.analyzingIngredients:
        return Icons.science_outlined;
      case ScanStage.generatingInsights:
        return Icons.insights_outlined;
      case ScanStage.done:
        return Icons.check_circle_outline;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim = Tween<double>(
      begin: 0.0,
      end: widget.stage.progress,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
    _progressCtrl.forward();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ScanLoadingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.stage != old.stage) {
      _progressFrom = old.stage.progress;
      _progressAnim = Tween<double>(
        begin: _progressFrom,
        end: widget.stage.progress,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
      _progressCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _scanLineCtrl.dispose();
    _progressCtrl.dispose();
    _shimmerCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.90),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Spinning arc + scan-line icon ────────────────────
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Spinning gradient arc
                        AnimatedBuilder(
                          animation: _spinCtrl,
                          builder: (_, __) => Transform.rotate(
                            angle: _spinCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(100, 100),
                              painter: _ArcPainter(color: c.primary),
                            ),
                          ),
                        ),

                        // Icon bubble with sweeping scan line
                        ClipOval(
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.primary.withValues(alpha: 0.12),
                                  ),
                                ),
                                // Sweeping horizontal scan line
                                AnimatedBuilder(
                                  animation: _scanLineCtrl,
                                  builder: (_, __) {
                                    final y = _scanLineCtrl.value * 72;
                                    return Positioned(
                                      top: y - 1,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              c.primary.withValues(alpha: 0.85),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Icon — fast cross-fade
                                Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                          opacity: anim,
                                          child: ScaleTransition(
                                            scale:
                                                Tween<double>(
                                                  begin: 0.7,
                                                  end: 1.0,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: anim,
                                                    curve: Curves.easeOut,
                                                  ),
                                                ),
                                            child: child,
                                          ),
                                        ),
                                    child: Icon(
                                      _iconFor(widget.stage),
                                      key: ValueKey(widget.stage),
                                      color: c.primary,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Stage label ───────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      widget.stage.label,
                      key: ValueKey(widget.stage.label),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 4),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      widget.stage.subtitle,
                      key: ValueKey(widget.stage.subtitle),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Progress bar with shimmer ─────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_progressAnim, _shimmerCtrl]),
                    builder: (_, __) {
                      final progress = _progressAnim.value.clamp(0.0, 1.0);
                      return Column(
                        children: [
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final barW = constraints.maxWidth;
                              final fillW = barW * progress;
                              final shimX =
                                  (_shimmerCtrl.value * (fillW + 60)) - 60;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 5,
                                  width: barW,
                                  child: Stack(
                                    children: [
                                      Container(color: Colors.white12),
                                      Container(
                                        width: fillW,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              c.primary.withValues(alpha: 0.7),
                                              c.primary,
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (progress > 0.02)
                                        Positioned(
                                          left: shimX,
                                          child: Container(
                                            width: 60,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Stage pills ───────────────────────────────────────
                  _StagePills(
                    current: widget.stage,
                    stages: _orderedStages,
                    activeColor: c.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Arc painter ────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint track
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Bright 270° arc with fade-in tail
    canvas.drawArc(
      rect,
      -math.pi / 2,
      1.5 * math.pi,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.0), color],
          startAngle: 0,
          endAngle: 1.5 * math.pi,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

// ── Stage pills ────────────────────────────────────────────────────────────

class _StagePills extends StatelessWidget {
  final ScanStage current;
  final List<ScanStage> stages;
  final Color activeColor;

  const _StagePills({
    required this.current,
    required this.stages,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final currentIdx = stages.indexOf(current);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stages.asMap().entries.map((e) {
        final isDone = e.key < currentIdx;
        final isActive = e.key == currentIdx;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            color: isDone
                ? const Color(0xFF22C55E)
                : isActive
                ? activeColor
                : Colors.white.withValues(alpha: 0.3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }).toList(),
    );
  }
}
