import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/scan/scan_viewmodel.dart';
import 'package:cal0appv2/views/widgets/scan_confirm_sheet.dart';
import 'package:cal0appv2/models/scan_result_model.dart';

// ── Angle slot definition ─────────────────────────────────────────────────

class _AngleSlot {
  final String id;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  File? image;

  _AngleSlot({
    required this.id,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = true,
    this.image,
  });

  bool get captured => image != null;
}

// ── Screen ────────────────────────────────────────────────────────────────

class MultiAngleCaptureScreen extends StatefulWidget {
  /// The Homepage scaffold context — needed to show the loading overlay and
  /// confirm sheet over the Homepage after this screen pops.
  final BuildContext scaffoldContext;

  const MultiAngleCaptureScreen({super.key, required this.scaffoldContext});

  @override
  State<MultiAngleCaptureScreen> createState() =>
      _MultiAngleCaptureScreenState();
}

class _MultiAngleCaptureScreenState extends State<MultiAngleCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  bool _showInstructions = true;
  bool _isAnalysing = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Three required + two optional slots
  late final List<_AngleSlot> _slots = [
    _AngleSlot(
      id: 'front',
      label: 'Front Panel',
      hint: 'Brand name, product type, weight',
      icon: Icons.crop_portrait,
      required: true,
    ),
    _AngleSlot(
      id: 'nutrition',
      label: 'Nutrition Facts',
      hint: 'Calories, protein, carbs, fat, sugar…',
      icon: Icons.table_chart_outlined,
      required: true,
    ),
    _AngleSlot(
      id: 'ingredients',
      label: 'Ingredients List',
      hint: 'Full ingredient text (may wrap to another side)',
      icon: Icons.list_alt_rounded,
      required: true,
    ),
    _AngleSlot(
      id: 'side',
      label: 'Side Panel',
      hint: 'Extra nutrition info or continued ingredients',
      icon: Icons.view_sidebar_outlined,
      required: false,
    ),
    _AngleSlot(
      id: 'closeup',
      label: 'Close-up',
      hint: 'Any fine print or blurry area you want re-scanned',
      icon: Icons.zoom_in,
      required: false,
    ),
  ];

  int get _capturedRequired =>
      _slots.where((s) => s.required && s.captured).length;
  int get _totalRequired => _slots.where((s) => s.required).length;
  bool get _canAnalyse => _capturedRequired >= _totalRequired;
  List<File> get _capturedFiles =>
      _slots.where((s) => s.captured).map((s) => s.image!).toList();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Capture a single angle ──────────────────────────────────────────────

  Future<void> _captureSlot(_AngleSlot slot) async {
    final source = await _pickImageSource();
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return;
    setState(() => slot.image = File(picked.path));
  }

  /// Shows a small action sheet letting the user choose Camera or Gallery.
  Future<ImageSource?> _pickImageSource() async {
    final c = C0Theme.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.of(sheetCtx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: c.primary),
              title: Text(
                'Take Photo',
                style: AppTextStyles.bodyCompact.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.primary),
              title: Text(
                'Choose from Gallery',
                style: AppTextStyles.bodyCompact.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trigger the multi-image scan pipeline ───────────────────────────────

  Future<void> _analyse() async {
    if (!_canAnalyse || _isAnalysing) return;
    setState(() => _isAnalysing = true);

    // Grab vm BEFORE popping — this widget's context dies on pop
    final vm = context.read<ScanViewModel>();
    final files = _capturedFiles;

    // Pop back to Homepage so the loading overlay is visible over it
    if (mounted) Navigator.of(context).pop();

    // Run the multi-image pipeline — overlay driven by vm.currentStage
    await vm.scanMultipleImages(files);

    final sc = widget.scaffoldContext;
    if (!sc.mounted) return;

    if (vm.errorMessage != null && vm.scannedText == null) {
      ScaffoldMessenger.of(sc).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
      );
      return;
    }

    showModalBottomSheet(
      context: sc,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: ScanConfirmSheet(
          initial: vm.extractedResult ?? ScanResultModel.empty,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Multi-Angle Scan',
          style: AppTextStyles.title.copyWith(
            color: c.textPrimary,
            fontSize: 17,
          ),
        ),
        actions: [
          // Help button re-shows instructions
          IconButton(
            icon: Icon(Icons.help_outline, color: c.textSecondary, size: 20),
            onPressed: () => setState(() => _showInstructions = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Main content ─────────────────────────────────────────────
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ProgressHeader(
                    captured: _capturedRequired,
                    total: _totalRequired,
                    primaryColor: c.primary,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _SlotCard(
                      slot: _slots[i],
                      index: i,
                      onCapture: () => _captureSlot(_slots[i]),
                    ),
                    childCount: _slots.length,
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed bottom button ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AnalyseButton(
              canAnalyse: _canAnalyse,
              capturedRequired: _capturedRequired,
              totalRequired: _totalRequired,
              pulse: _pulse,
              onPressed: _analyse,
            ),
          ),

          // ── Instruction overlay ───────────────────────────────────────
          if (_showInstructions)
            _InstructionOverlay(
              onDismiss: () => setState(() => _showInstructions = false),
            ),
        ],
      ),
    );
  }
}

// ── Progress header ────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int captured;
  final int total;
  final Color primaryColor;

  const _ProgressHeader({
    required this.captured,
    required this.total,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final progress = total > 0 ? captured / total : 0.0;
    final done = captured >= total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: done ? primaryColor.withValues(alpha: 0.08) : c.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: done ? primaryColor.withValues(alpha: 0.3) : c.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.camera_alt_outlined,
                color: done ? primaryColor : c.textSecondary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  done
                      ? 'All required angles captured — ready to analyse!'
                      : 'Capture $total angles for best accuracy',
                  style: AppTextStyles.bodyCompact.copyWith(
                    color: done ? primaryColor : c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$captured / $total',
                style: AppTextStyles.bodyCompact.copyWith(
                  color: done ? primaryColor : c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: c.divider,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'More angles → more complete text extraction → more accurate AI verdict',
            style: AppTextStyles.micro.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slot card ──────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final _AngleSlot slot;
  final int index;
  final VoidCallback onCapture;

  const _SlotCard({
    required this.slot,
    required this.index,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final captured = slot.captured;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: captured
              ? c.success.withValues(alpha: 0.5)
              : slot.required
              ? c.divider
              : c.divider.withValues(alpha: 0.5),
          width: captured ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onCapture,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Thumbnail or placeholder
              _SlotThumbnail(slot: slot),
              const SizedBox(width: AppSpacing.md),

              // Label + hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          slot.label,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (slot.required)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              'Required',
                              style: AppTextStyles.micro.copyWith(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.slate.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              'Optional',
                              style: AppTextStyles.micro.copyWith(
                                color: c.slate,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.hint,
                      style: AppTextStyles.micro.copyWith(
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Action icon(s) — show both camera + gallery when not yet
              // captured, so the gallery option is visible without tapping.
              captured
                  ? Icon(Icons.refresh, color: c.success, size: 20)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: c.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.photo_library_outlined,
                          color: c.primary.withValues(alpha: 0.6),
                          size: 16,
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotThumbnail extends StatelessWidget {
  final _AngleSlot slot;
  const _SlotThumbnail({required this.slot});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    if (slot.captured) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.file(
              slot.image!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: c.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 11),
            ),
          ),
        ],
      );
    }

    // Empty placeholder
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: slot.required ? c.primary.withValues(alpha: 0.3) : c.divider,
          style: BorderStyle.solid,
        ),
      ),
      child: Icon(
        slot.icon,
        color: slot.required
            ? c.primary.withValues(alpha: 0.5)
            : c.slate.withValues(alpha: 0.4),
        size: 26,
      ),
    );
  }
}

// ── Analyse button ─────────────────────────────────────────────────────────

class _AnalyseButton extends StatelessWidget {
  final bool canAnalyse;
  final int capturedRequired;
  final int totalRequired;
  final Animation<double> pulse;
  final VoidCallback onPressed;

  const _AnalyseButton({
    required this.canAnalyse,
    required this.capturedRequired,
    required this.totalRequired,
    required this.pulse,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: canAnalyse
          ? ScaleTransition(
              scale: pulse,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    'Analyse $capturedRequired Angles',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null, // disabled
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.divider,
                      disabledBackgroundColor: c.divider,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Capture ${totalRequired - capturedRequired} more required angle'
                      '${totalRequired - capturedRequired == 1 ? '' : 's'} to continue',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Instruction overlay ────────────────────────────────────────────────────

class _InstructionOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _InstructionOverlay({required this.onDismiss});

  @override
  State<_InstructionOverlay> createState() => _InstructionOverlayState();
}

class _InstructionOverlayState extends State<_InstructionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const _steps = [
    _Step(
      Icons.touch_app_outlined,
      'Tip: Camera or Gallery',
      'Tap any slot below — you can take a new photo or choose an existing one from your gallery.',
    ),
    _Step(
      Icons.crop_portrait,
      '1. Front Panel',
      'Capture the front of the product showing the brand name, type, and net weight.',
    ),
    _Step(
      Icons.table_chart_outlined,
      '2. Nutrition Facts',
      'Photograph the nutrition facts panel clearly. Hold steady to avoid blur.',
    ),
    _Step(
      Icons.list_alt_rounded,
      '3. Ingredients',
      'Capture the full ingredients list. Multiple angles help if the text wraps around the tub.',
    ),
    _Step(
      Icons.auto_awesome,
      'Why 3 angles?',
      'Each photo adds more text. The system merges all angles, removing duplicates, so the AI sees the most complete label possible before making a verdict.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);

    return FadeTransition(
      opacity: _anim,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent tap-through
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: c.primary, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'How Multi-Angle Scan Works',
                            style: AppTextStyles.title.copyWith(
                              color: c.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Steps
                    ..._steps.map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.sm + 2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                step.icon,
                                color: c.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: AppTextStyles.bodyCompact.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    step.body,
                                    style: AppTextStyles.micro.copyWith(
                                      color: c.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Got it — start capturing',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  const _Step(this.icon, this.title, this.body);
}
