import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import 'package:cal0appv2/viewModels/foodlog/food_history_viewmodel.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/views/widgets/app_text_field.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/macro_progress_bar.dart';
import 'package:cal0appv2/views/widgets/source_badge.dart';

enum _Verdict { authentic, spiked, plantBased, unknown }

class _ParsedVerdict {
  final _Verdict verdict;
  final double confidence; // 0–1, 0 if not stored
  const _ParsedVerdict(this.verdict, this.confidence);

  static _ParsedVerdict from(String? raw) {
    if (raw == null || raw.isEmpty)
      return const _ParsedVerdict(_Verdict.unknown, 0);
    final upper = raw.toUpperCase();
    final confMatch = RegExp(r'(\d+)%').firstMatch(raw);
    final conf = confMatch != null
        ? (int.tryParse(confMatch.group(1) ?? '0') ?? 0) / 100.0
        : 0.0;

    if (upper.contains('SPIKED')) return _ParsedVerdict(_Verdict.spiked, conf);
    if (upper.contains('PLANT'))
      return _ParsedVerdict(_Verdict.plantBased, conf);
    if (upper.contains('AUTHENTIC'))
      return _ParsedVerdict(_Verdict.authentic, conf);
    return _ParsedVerdict(_Verdict.unknown, conf);
  }
}

// ── Rule-based ingredient detection (mirrors scan_viewmodel.dart) ─────────────
// Kept local so food_detail_view has no dependency on ScanViewModel at runtime.

class _DetectedIng {
  final String name;
  final String category;
  final String explanation;
  final bool isAmSpiking;
  const _DetectedIng({
    required this.name,
    required this.category,
    required this.explanation,
    required this.isAmSpiking,
  });
}

const _ingDatabase = [
  _DetectedIng(
    name: 'Glycine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Cheap amino acid that inflates lab protein tests without real muscle benefit.',
  ),
  _DetectedIng(
    name: 'Taurine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Registers as protein on Kjeldahl tests but does not contribute to MPS.',
  ),
  _DetectedIng(
    name: 'Creatine Monohydrate',
    category: 'Potential Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Contains nitrogen — can inflate protein readings. Legitimate supplement but suspicious in protein powder.',
  ),
  _DetectedIng(
    name: 'Beta-Alanine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Non-essential amino acid that contributes nitrogen without being a quality protein source.',
  ),
  _DetectedIng(
    name: 'L-Glutamine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Free amino acid sometimes added in excess to boost nitrogen content.',
  ),
  _DetectedIng(
    name: 'Arginine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation: 'Free-form amino acid used to boost nitrogen scores.',
  ),
  _DetectedIng(
    name: 'Alanine',
    category: 'Amino Spiking Agent',
    isAmSpiking: true,
    explanation:
        'Cheap non-essential amino acid used to inflate protein readings.',
  ),
  _DetectedIng(
    name: 'Leucine',
    category: 'Amino Spiking Agent / BCAA',
    isAmSpiking: true,
    explanation:
        'Excess free-form leucine on a protein label can indicate spiking.',
  ),
  _DetectedIng(
    name: 'Sucralose',
    category: 'Artificial Sweetener',
    isAmSpiking: false,
    explanation: 'Zero-calorie chlorinated sugar. Common in protein powders.',
  ),
  _DetectedIng(
    name: 'Acesulfame Potassium',
    category: 'Artificial Sweetener',
    isAmSpiking: false,
    explanation:
        'Also listed as Ace-K or E950. Often used alongside sucralose.',
  ),
  _DetectedIng(
    name: 'Aspartame',
    category: 'Artificial Sweetener',
    isAmSpiking: false,
    explanation: 'Common artificial sweetener. Avoid if you have PKU.',
  ),
  _DetectedIng(
    name: 'Maltodextrin',
    category: 'Filler / High GI Carb',
    isAmSpiking: false,
    explanation: 'High-glycaemic carbohydrate often used as a filler.',
  ),
  _DetectedIng(
    name: 'Soy Lecithin',
    category: 'Emulsifier',
    isAmSpiking: false,
    explanation: 'Common emulsifier. Concern for those with soy allergies.',
  ),
];

const _ingAliases = {
  'Glycine': ['glycine'],
  'Taurine': ['taurine'],
  'Creatine Monohydrate': ['creatine monohydrate', 'creatine', 'creatine hcl'],
  'Beta-Alanine': ['beta-alanine', 'beta alanine'],
  'L-Glutamine': ['l-glutamine', 'glutamine'],
  'Arginine': ['arginine', 'l-arginine'],
  'Alanine': ['alanine', 'l-alanine'],
  'Leucine': ['leucine', 'l-leucine'],
  'Sucralose': ['sucralose'],
  'Acesulfame Potassium': ['acesulfame potassium', 'acesulfame-k', 'ace-k'],
  'Aspartame': ['aspartame'],
  'Maltodextrin': ['maltodextrin'],
  'Soy Lecithin': ['soy lecithin', 'soya lecithin'],
};

List<_DetectedIng> _detectIngredients(String text) {
  if (text.isEmpty) return [];
  final lower = text.toLowerCase();
  final found = <_DetectedIng>[];
  for (final ing in _ingDatabase) {
    final aliases = _ingAliases[ing.name] ?? [];
    if (aliases.any((a) => lower.contains(a))) found.add(ing);
  }
  return found;
}

// ══════════════════════════════════════════════════════════════════════════════
// FoodDetailView
// ══════════════════════════════════════════════════════════════════════════════

class FoodDetailView extends StatefulWidget {
  final FoodLogModel log;
  const FoodDetailView({super.key, required this.log});

  @override
  State<FoodDetailView> createState() => _FoodDetailViewState();
}

class _FoodDetailViewState extends State<FoodDetailView> {
  late FoodLogModel _log;

  @override
  void initState() {
    super.initState();
    _log = widget.log;
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final parsed = _ParsedVerdict.from(_log.scanAnalysisResult);

    // Ingredient text is stored in scanAnalysisResult for legacy logs,
    // or may not be stored at all — we do our best with what we have.
    // The rule-based detector runs on the raw scanAnalysisResult string
    // so even old logs get ingredient chips if the text was saved.
    final ingredientSource = _log.scanAnalysisResult ?? '';
    final detectedIngs = _detectIngredients(ingredientSource);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.header,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _log.foodLogName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit,
              color: Colors.white,
              size: AppSizes.fieldIconSize,
            ),
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scanned image
            if (_log.isScanned &&
                _log.imagePath != null &&
                _log.imagePath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.file(
                  File(_log.imagePath!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (_log.isScanned && _log.imagePath != null)
              const SizedBox(height: AppSpacing.lg),

            // ── Meta card ─────────────────────────────────────────
            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Source',
                    value: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [SourceBadge(source: _log.source)],
                    ),
                  ),
                  _InfoRow(
                    label: 'Date',
                    value: Text(
                      DateFormat('d MMM yyyy, h:mm a').format(_log.loggedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (_log.servingSize != null)
                    _InfoRow(
                      label: 'Serving',
                      value: Text(
                        '${_log.servingSize}${_log.servingUnit}',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  if (_log.isScanned && _log.scanConfidence != null)
                    _InfoRow(
                      label: 'OCR Confidence',
                      value: Text(
                        '${(_log.scanConfidence! * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── AI verdict card (scanned only) ────────────────────
            if (_log.isScanned && _log.scanAnalysisResult != null) ...[
              _AiVerdictSection(
                parsed: parsed,
                detectedIngredients: detectedIngs,
                rawResult: _log.scanAnalysisResult!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Nutrition ─────────────────────────────────────────
            Text(
              'NUTRITION',
              style: AppTextStyles.sectionTitle.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  MacroProgressBar(
                    label: 'Calories',
                    value: _log.calorieIntake.toDouble(),
                    max: 2000,
                    unit: 'kcal',
                    color: c.primary,
                  ),
                  MacroProgressBar(
                    label: 'Protein',
                    value: _log.protein,
                    max: 150,
                    color: c.success,
                  ),
                  MacroProgressBar(
                    label: 'Carbs',
                    value: _log.carbs,
                    max: 250,
                    color: C0Theme.macroCarbs,
                  ),
                  MacroProgressBar(
                    label: 'Fat',
                    value: _log.fats,
                    max: 65,
                    color: c.slate,
                  ),
                  if (_log.sugar > 0)
                    MacroProgressBar(
                      label: 'Sugar',
                      value: _log.sugar,
                      max: 50,
                      color: C0Theme.macroSugar,
                    ),
                  if (_log.fiber > 0)
                    MacroProgressBar(
                      label: 'Fiber',
                      value: _log.fiber,
                      max: 28,
                      color: const Color(0xFF10B981),
                    ),
                  if (_log.saturatedFat > 0)
                    MacroProgressBar(
                      label: 'Saturated Fat',
                      value: _log.saturatedFat,
                      max: 20,
                      color: const Color(0xFFEF4444),
                    ),
                  if (_log.sodium > 0)
                    MacroProgressBar(
                      label: 'Sodium',
                      value: _log.sodium,
                      max: 2300,
                      unit: 'mg',
                      color: C0Theme.macroSodium,
                    ),
                  if (_log.potassium > 0)
                    MacroProgressBar(
                      label: 'Potassium',
                      value: _log.potassium,
                      max: 4700,
                      unit: 'mg',
                      color: const Color(0xFF8B5CF6),
                    ),
                  if (_log.calcium > 0)
                    MacroProgressBar(
                      label: 'Calcium',
                      value: _log.calcium,
                      max: 1000,
                      unit: 'mg',
                      color: const Color(0xFF14B8A6),
                    ),
                  if (_log.iron > 0)
                    MacroProgressBar(
                      label: 'Iron',
                      value: _log.iron,
                      max: 18,
                      unit: 'mg',
                      color: const Color(0xFFF87171),
                    ),
                  if (_log.magnesium > 0)
                    MacroProgressBar(
                      label: 'Magnesium',
                      value: _log.magnesium,
                      max: 420,
                      unit: 'mg',
                      color: const Color(0xFF34D399),
                    ),
                  if (_log.zinc > 0)
                    MacroProgressBar(
                      label: 'Zinc',
                      value: _log.zinc,
                      max: 11,
                      unit: 'mg',
                      color: const Color(0xFFFBBF24),
                    ),
                  if (_log.vitaminC > 0)
                    MacroProgressBar(
                      label: 'Vitamin C',
                      value: _log.vitaminC,
                      max: 90,
                      unit: 'mg',
                      color: const Color(0xFFF97316),
                    ),
                  if (_log.vitaminD > 0)
                    MacroProgressBar(
                      label: 'Vitamin D',
                      value: _log.vitaminD,
                      max: 20,
                      unit: 'µg',
                      color: const Color(0xFFEAB308),
                    ),
                  if (_log.caffeine > 0)
                    MacroProgressBar(
                      label: 'Caffeine',
                      value: _log.caffeine,
                      max: 400,
                      unit: 'mg',
                      color: const Color(0xFF78716C),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        log: _log,
        onSaved: (updated) async {
          final uid = context.read<AuthViewModel>().currentUid ?? '';
          await context.read<FoodHistoryViewModel>().update(uid, updated);
          // Rebuild the verdict section with updated log
          setState(() => _log = updated);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AI Verdict Section  — the full breakdown card
// ══════════════════════════════════════════════════════════════════════════════

class _AiVerdictSection extends StatefulWidget {
  final _ParsedVerdict parsed;
  final List<_DetectedIng> detectedIngredients;
  final String rawResult;

  const _AiVerdictSection({
    required this.parsed,
    required this.detectedIngredients,
    required this.rawResult,
  });

  @override
  State<_AiVerdictSection> createState() => _AiVerdictSectionState();
}

class _AiVerdictSectionState extends State<_AiVerdictSection> {
  bool _showIngredients = true;

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final cfg = _verdictConfig(widget.parsed, c);
    final hasAmSpiking = widget.detectedIngredients.any((d) => d.isAmSpiking);
    final pct = widget.parsed.confidence > 0
        ? '${(widget.parsed.confidence * 100).toStringAsFixed(0)}%'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main verdict card ─────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cfg.bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cfg.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: cfg.border.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top badge bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: cfg.accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl - 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cfg.badgeIcon, color: Colors.white, size: 14),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      cfg.badge,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    // Big icon
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: cfg.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cfg.accent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(cfg.icon, color: cfg.accent, size: 34),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      cfg.headline,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title.copyWith(
                        color: cfg.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      pct != null ? '${cfg.sub} · $pct confidence' : cfg.sub,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyCompact.copyWith(
                        color: cfg.accent.withValues(alpha: 0.75),
                      ),
                    ),

                    // Confidence bar
                    if (widget.parsed.confidence > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ConfBar(
                        confidence: widget.parsed.confidence,
                        color: cfg.accent,
                      ),
                    ],

                    // Spiking agents chip list
                    if (hasAmSpiking) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: cfg.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: cfg.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected spiking agents:',
                              style: AppTextStyles.caption.copyWith(
                                color: cfg.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: widget.detectedIngredients
                                  .where((d) => d.isAmSpiking)
                                  .map(
                                    (d) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cfg.accent.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                        border: Border.all(
                                          color: cfg.accent.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        d.name,
                                        style: AppTextStyles.micro.copyWith(
                                          color: cfg.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // What this means
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 13,
                                color: cfg.accent,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'What this means',
                                style: AppTextStyles.caption.copyWith(
                                  color: cfg.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            cfg.explanation,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          if (widget.parsed.verdict != _Verdict.unknown) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'This is an AI-based estimate from the original scan, not a lab test. '
                              'Edit the entry above to correct any details.',
                              style: AppTextStyles.micro.copyWith(
                                color: c.textSecondary.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Detected ingredient breakdown ─────────────────────────
        if (widget.detectedIngredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _IngredientBreakdown(
            ingredients: widget.detectedIngredients,
            expanded: _showIngredients,
            onToggle: () =>
                setState(() => _showIngredients = !_showIngredients),
          ),
        ],
      ],
    );
  }
}

// ── Verdict config ─────────────────────────────────────────────────────────

class _VConfig {
  final Color bg, border, accent;
  final IconData badgeIcon, icon;
  final String badge, headline, sub, explanation;
  const _VConfig({
    required this.bg,
    required this.border,
    required this.accent,
    required this.badgeIcon,
    required this.icon,
    required this.badge,
    required this.headline,
    required this.sub,
    required this.explanation,
  });
}

_VConfig _verdictConfig(_ParsedVerdict p, C0Colors c) {
  switch (p.verdict) {
    case _Verdict.authentic:
      return const _VConfig(
        bg: Color(0xFFECFDF5),
        border: Color(0xFF22C55E),
        accent: Color(0xFF16A34A),
        badgeIcon: Icons.verified,
        icon: Icons.shield_rounded,
        badge: 'AUTHENTIC PRODUCT',
        headline: 'Looks Authentic ✓',
        sub: 'No amino spiking detected',
        explanation:
            'The AI found no suspicious nitrogen-inflating amino acids in the ingredient list at the time of scanning. This product appeared to be genuine whey.',
      );
    case _Verdict.spiked:
      return const _VConfig(
        bg: Color(0xFFFEF2F2),
        border: Color(0xFFEF4444),
        accent: Color(0xFFDC2626),
        badgeIcon: Icons.warning_rounded,
        icon: Icons.dangerous_rounded,
        badge: 'AMINO SPIKING DETECTED',
        headline: '⚠ Spiking Detected',
        sub: 'Suspicious ingredients found',
        explanation:
            'The AI detected cheap amino acids commonly used to inflate protein readings on lab tests. These do not provide the same muscle-building benefit as real whey protein.',
      );
    case _Verdict.plantBased:
      return const _VConfig(
        bg: Color(0xFFF0FDF4),
        border: Color(0xFF4ADE80),
        accent: Color(0xFF15803D),
        badgeIcon: Icons.eco,
        icon: Icons.eco_rounded,
        badge: 'PLANT-BASED PROTEIN',
        headline: '🌱 Plant-Based',
        sub: 'Not whey protein',
        explanation:
            'This product appears to contain plant-based protein (pea, rice, soy, etc.) rather than whey. No amino spiking concern specific to whey, but verify the label matches your goals.',
      );
    case _Verdict.unknown:
      return _VConfig(
        bg: c.card,
        border: c.divider,
        accent: c.textSecondary,
        badgeIcon: Icons.info_outline,
        icon: Icons.help_center_outlined,
        badge: 'RESULT UNAVAILABLE',
        headline: 'No AI Result',
        sub: 'Analysis was not recorded',
        explanation:
            'No AI verdict was saved for this entry. This may be a manually logged food or a scan from an older version of the app.',
      );
  }
}

// ── Confidence bar ─────────────────────────────────────────────────────────

class _ConfBar extends StatelessWidget {
  final double confidence;
  final Color color;
  const _ConfBar({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final label = confidence >= 0.80
        ? 'High'
        : confidence >= 0.50
        ? 'Moderate'
        : 'Low';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Confidence',
              style: AppTextStyles.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}% — $label confidence',
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Ingredient breakdown ───────────────────────────────────────────────────

class _IngredientBreakdown extends StatelessWidget {
  final List<_DetectedIng> ingredients;
  final bool expanded;
  final VoidCallback onToggle;
  const _IngredientBreakdown({
    required this.ingredients,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final hasAmSpiking = ingredients.any((i) => i.isAmSpiking);
    final hColor = hasAmSpiking ? c.warning : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: hColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    hasAmSpiking ? Icons.warning_rounded : Icons.info_outline,
                    color: hColor,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAmSpiking
                              ? 'Suspicious Ingredients'
                              : 'Notable Ingredients',
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hColor,
                          ),
                        ),
                        Text(
                          '${ingredients.length} detected from original scan',
                          style: AppTextStyles.micro.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: c.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: ingredients.map((i) => _IngCard(ing: i)).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _IngCard extends StatefulWidget {
  final _DetectedIng ing;
  const _IngCard({required this.ing});
  @override
  State<_IngCard> createState() => _IngCardState();
}

class _IngCardState extends State<_IngCard> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final bColor = widget.ing.isAmSpiking ? c.warning : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _show = !_show),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      widget.ing.isAmSpiking
                          ? '⚠ Spiking Agent'
                          : widget.ing.category,
                      style: AppTextStyles.micro.copyWith(
                        color: bColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.ing.name,
                      style: AppTextStyles.bodyCompact.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _show
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm + 2,
                0,
                AppSpacing.sm + 2,
                AppSpacing.sm + 2,
              ),
              child: Text(
                widget.ing.explanation,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit sheet (unchanged from existing — all 30 fields + collapsible sections)
// ══════════════════════════════════════════════════════════════════════════════

class _EditSheet extends StatefulWidget {
  final FoodLogModel log;
  final Future<void> Function(FoodLogModel updated) onSaved;
  const _EditSheet({required this.log, required this.onSaved});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fats;
  late final TextEditingController _sodium;
  late final TextEditingController _fiber;
  late final TextEditingController _sugar;
  late final TextEditingController _addedSugar;
  late final TextEditingController _saturatedFat;
  late final TextEditingController _transFat;
  late final TextEditingController _unsaturatedFat;
  late final TextEditingController _omega3;
  late final TextEditingController _omega6;
  late final TextEditingController _cholesterol;
  late final TextEditingController _potassium;
  late final TextEditingController _calcium;
  late final TextEditingController _iron;
  late final TextEditingController _magnesium;
  late final TextEditingController _zinc;
  late final TextEditingController _phosphorus;
  late final TextEditingController _selenium;
  late final TextEditingController _vitaminA;
  late final TextEditingController _vitaminB1;
  late final TextEditingController _vitaminB2;
  late final TextEditingController _vitaminB3;
  late final TextEditingController _vitaminB6;
  late final TextEditingController _vitaminB12;
  late final TextEditingController _vitaminC;
  late final TextEditingController _vitaminD;
  late final TextEditingController _vitaminE;
  late final TextEditingController _vitaminK;
  late final TextEditingController _folate;
  late final TextEditingController _waterMl;
  late final TextEditingController _caffeine;
  late final TextEditingController _servingSize;

  bool _isSaving = false;
  bool _showExtMacros = false;
  bool _showMinerals = false;
  bool _showVitamins = false;
  bool _showOther = false;

  TextEditingController _c(double v) =>
      TextEditingController(text: v == 0 ? '' : v.toString());
  double _d(TextEditingController ctrl, double fallback) =>
      double.tryParse(ctrl.text.trim()) ?? fallback;

  @override
  void initState() {
    super.initState();
    final l = widget.log;
    _name = TextEditingController(text: l.foodLogName);
    _calories = TextEditingController(
      text: l.calorieIntake == 0 ? '' : l.calorieIntake.toString(),
    );
    _protein = _c(l.protein);
    _carbs = _c(l.carbs);
    _fats = _c(l.fats);
    _sodium = _c(l.sodium);
    _fiber = _c(l.fiber);
    _sugar = _c(l.sugar);
    _addedSugar = _c(l.addedSugar);
    _saturatedFat = _c(l.saturatedFat);
    _transFat = _c(l.transFat);
    _unsaturatedFat = _c(l.unsaturatedFat);
    _omega3 = _c(l.omega3);
    _omega6 = _c(l.omega6);
    _cholesterol = _c(l.cholesterol);
    _potassium = _c(l.potassium);
    _calcium = _c(l.calcium);
    _iron = _c(l.iron);
    _magnesium = _c(l.magnesium);
    _zinc = _c(l.zinc);
    _phosphorus = _c(l.phosphorus);
    _selenium = _c(l.selenium);
    _vitaminA = _c(l.vitaminA);
    _vitaminB1 = _c(l.vitaminB1);
    _vitaminB2 = _c(l.vitaminB2);
    _vitaminB3 = _c(l.vitaminB3);
    _vitaminB6 = _c(l.vitaminB6);
    _vitaminB12 = _c(l.vitaminB12);
    _vitaminC = _c(l.vitaminC);
    _vitaminD = _c(l.vitaminD);
    _vitaminE = _c(l.vitaminE);
    _vitaminK = _c(l.vitaminK);
    _folate = _c(l.folate);
    _waterMl = _c(l.waterMl);
    _caffeine = _c(l.caffeine);
    _servingSize = TextEditingController(
      text: (l.servingSize != null && l.servingSize! > 0)
          ? l.servingSize.toString()
          : '',
    );
  }

  @override
  void dispose() {
    for (final ctrl in [
      _name,
      _calories,
      _protein,
      _carbs,
      _fats,
      _sodium,
      _fiber,
      _sugar,
      _addedSugar,
      _saturatedFat,
      _transFat,
      _unsaturatedFat,
      _omega3,
      _omega6,
      _cholesterol,
      _potassium,
      _calcium,
      _iron,
      _magnesium,
      _zinc,
      _phosphorus,
      _selenium,
      _vitaminA,
      _vitaminB1,
      _vitaminB2,
      _vitaminB3,
      _vitaminB6,
      _vitaminB12,
      _vitaminC,
      _vitaminD,
      _vitaminE,
      _vitaminK,
      _folate,
      _waterMl,
      _caffeine,
      _servingSize,
    ])
      ctrl.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController ctrl, {
    required String label,
    required String hint,
  }) =>
      AppTextField(controller: ctrl, label: label, hint: hint, isNumber: true);

  Widget _row2(
    TextEditingController c1,
    String l1,
    String h1,
    TextEditingController c2,
    String l2,
    String h2,
  ) => Row(
    children: [
      Expanded(
        child: _field(c1, label: l1, hint: h1),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _field(c2, label: l2, hint: h2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Edit Food Entry',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SLabel(
                    title: 'Required',
                    subtitle: 'Fill in any fields you have',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _name,
                    label: 'Food Name',
                    hint: 'e.g. Chicken Rice',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _field(_calories, label: 'Calories', hint: 'kcal'),
                  const SizedBox(height: AppSpacing.sm),
                  _row2(_protein, 'Protein', 'g', _carbs, 'Carbs', 'g'),
                  const SizedBox(height: AppSpacing.sm),
                  _row2(_fats, 'Fat', 'g', _sodium, 'Sodium', 'mg'),
                  const SizedBox(height: AppSpacing.lg),
                  _CSection(
                    title: 'Extended Macros',
                    subtitle: '9 optional fields',
                    expanded: _showExtMacros,
                    onToggle: () =>
                        setState(() => _showExtMacros = !_showExtMacros),
                    children: [
                      _row2(_fiber, 'Fiber', 'g', _sugar, 'Sugar', 'g'),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _addedSugar,
                        'Added Sugar',
                        'g',
                        _saturatedFat,
                        'Saturated Fat',
                        'g',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _transFat,
                        'Trans Fat',
                        'g',
                        _unsaturatedFat,
                        'Unsaturated Fat',
                        'g',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(_omega3, 'Omega-3', 'g', _omega6, 'Omega-6', 'g'),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_cholesterol, label: 'Cholesterol', hint: 'mg'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CSection(
                    title: 'Minerals',
                    subtitle: '7 optional fields',
                    expanded: _showMinerals,
                    onToggle: () =>
                        setState(() => _showMinerals = !_showMinerals),
                    children: [
                      _row2(
                        _potassium,
                        'Potassium',
                        'mg',
                        _calcium,
                        'Calcium',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(_iron, 'Iron', 'mg', _magnesium, 'Magnesium', 'mg'),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _zinc,
                        'Zinc',
                        'mg',
                        _phosphorus,
                        'Phosphorus',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_selenium, label: 'Selenium', hint: 'µg'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CSection(
                    title: 'Vitamins',
                    subtitle: '11 optional fields',
                    expanded: _showVitamins,
                    onToggle: () =>
                        setState(() => _showVitamins = !_showVitamins),
                    children: [
                      _row2(
                        _vitaminA,
                        'Vitamin A',
                        'µg RAE',
                        _vitaminB1,
                        'Vitamin B1',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminB2,
                        'Vitamin B2',
                        'mg',
                        _vitaminB3,
                        'Vitamin B3',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminB6,
                        'Vitamin B6',
                        'mg',
                        _vitaminB12,
                        'Vitamin B12',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminC,
                        'Vitamin C',
                        'mg',
                        _vitaminD,
                        'Vitamin D',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _row2(
                        _vitaminE,
                        'Vitamin E',
                        'mg',
                        _vitaminK,
                        'Vitamin K',
                        'µg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(_folate, label: 'Folate', hint: 'µg DFE'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CSection(
                    title: 'Other',
                    subtitle: 'Water, caffeine & serving size',
                    expanded: _showOther,
                    onToggle: () => setState(() => _showOther = !_showOther),
                    children: [
                      _row2(
                        _waterMl,
                        'Water',
                        'ml',
                        _caffeine,
                        'Caffeine',
                        'mg',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _field(
                        _servingSize,
                        label: 'Serving Size',
                        hint: 'g / ml',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: _isSaving ? 'Saving…' : 'Save Changes',
                    onPressed: _isSaving ? null : () => _save(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final l = widget.log;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a food name.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final updated = FoodLogModel(
      foodLogID: l.foodLogID,
      userId: l.userId,
      foodLogName: name,
      calorieIntake: int.tryParse(_calories.text.trim()) ?? 0,
      foodLogDate: l.foodLogDate,
      loggedAt: l.loggedAt,
      source: l.source,
      imagePath: l.imagePath,
      scanConfidence: l.scanConfidence,
      scanAnalysisResult: l.scanAnalysisResult,
      protein: _d(_protein, l.protein),
      carbs: _d(_carbs, l.carbs),
      fats: _d(_fats, l.fats),
      sodium: _d(_sodium, l.sodium),
      fiber: _d(_fiber, l.fiber),
      sugar: _d(_sugar, l.sugar),
      addedSugar: _d(_addedSugar, l.addedSugar),
      saturatedFat: _d(_saturatedFat, l.saturatedFat),
      transFat: _d(_transFat, l.transFat),
      unsaturatedFat: _d(_unsaturatedFat, l.unsaturatedFat),
      omega3: _d(_omega3, l.omega3),
      omega6: _d(_omega6, l.omega6),
      cholesterol: _d(_cholesterol, l.cholesterol),
      potassium: _d(_potassium, l.potassium),
      calcium: _d(_calcium, l.calcium),
      iron: _d(_iron, l.iron),
      magnesium: _d(_magnesium, l.magnesium),
      zinc: _d(_zinc, l.zinc),
      phosphorus: _d(_phosphorus, l.phosphorus),
      selenium: _d(_selenium, l.selenium),
      vitaminA: _d(_vitaminA, l.vitaminA),
      vitaminB1: _d(_vitaminB1, l.vitaminB1),
      vitaminB2: _d(_vitaminB2, l.vitaminB2),
      vitaminB3: _d(_vitaminB3, l.vitaminB3),
      vitaminB6: _d(_vitaminB6, l.vitaminB6),
      vitaminB12: _d(_vitaminB12, l.vitaminB12),
      vitaminC: _d(_vitaminC, l.vitaminC),
      vitaminD: _d(_vitaminD, l.vitaminD),
      vitaminE: _d(_vitaminE, l.vitaminE),
      vitaminK: _d(_vitaminK, l.vitaminK),
      folate: _d(_folate, l.folate),
      waterMl: _d(_waterMl, l.waterMl),
      caffeine: _d(_caffeine, l.caffeine),
      servingSize: _servingSize.text.trim().isEmpty
          ? l.servingSize
          : double.tryParse(_servingSize.text.trim()),
      servingUnit: l.servingUnit,
    );
    await widget.onSaved(updated);
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String title, subtitle;
  const _SLabel({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.sectionTitle.copyWith(color: c.primary),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.tiny.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _CSection extends StatelessWidget {
  final String title, subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _CSection({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.formBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.tiny.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: c.formBorder, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  ...children,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: C0Theme.slateGrey),
        ),
        value,
      ],
    ),
  );
}
