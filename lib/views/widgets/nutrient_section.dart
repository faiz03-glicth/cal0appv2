import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/viewModels/dashboard/dashboard_viewmodel.dart';
import 'package:cal0appv2/models/nutrient_totals.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';

// ── Daily Reference Values (FDA / WHO 2024) ────────────────────────────────

class _DRV {
  // Macros
  static const double protein = 50; // g
  static const double carbs = 275; // g
  static const double fiber = 28; // g
  static const double sugar = 50; // g (total)
  static const double addedSugar = 25; // g (WHO)
  static const double fat = 78; // g
  static const double saturatedFat = 20; // g
  static const double transFat = 0; // g (as low as possible)
  static const double cholesterol = 300; // mg
  // Minerals
  static const double sodium = 2300; // mg
  static const double potassium = 4700; // mg
  static const double calcium = 1000; // mg
  static const double iron = 18; // mg
  static const double magnesium = 420; // mg
  static const double zinc = 11; // mg
  static const double phosphorus = 1250; // mg
  static const double selenium = 55; // µg
  // Vitamins
  static const double vitaminA = 900; // µg RAE
  static const double vitaminB1 = 1.2; // mg
  static const double vitaminB2 = 1.3; // mg
  static const double vitaminB3 = 16; // mg
  static const double vitaminB6 = 1.7; // mg
  static const double vitaminB12 = 2.4; // µg
  static const double vitaminC = 90; // mg
  static const double vitaminD = 20; // µg
  static const double vitaminE = 15; // mg
  static const double vitaminK = 120; // µg
  static const double folate = 400; // µg DFE
  // Other
  static const double water = 2500; // ml (2.5 L)
  static const double caffeine = 400; // mg (safe limit)
}

// ── Main widget ────────────────────────────────────────────────────────────

class NutrientSection extends StatefulWidget {
  const NutrientSection({super.key});
  @override
  State<NutrientSection> createState() => _NutrientSectionState();
}

class _NutrientSectionState extends State<NutrientSection> {
  // Track which groups are expanded
  final _expanded = <String, bool>{
    'Macros': true,
    'Fats & Lipids': false,
    'Minerals': false,
    'Vitamins': false,
    'Other': false,
  };

  @override
  Widget build(BuildContext context) {
    return Selector<FoodLogViewModel, NutrientTotals>(
      selector: (_, vm) => vm.totals,
      builder: (context, totals, _) {
        final dashVm = context.read<DashboardViewModel>();
        final calTarget = dashVm.calorieTarget.toDouble();
        final macros = dashVm.macroTargets;

        return AppCard(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────
              _SectionHeader(totals: totals),

              // ── Groups ─────────────────────────────────────────────────
              _NutrientGroup(
                title: 'Macros',
                expanded: _expanded['Macros']!,
                onToggle: () =>
                    setState(() => _expanded['Macros'] = !_expanded['Macros']!),
                rows: _macroRows(totals, calTarget, macros),
              ),

              _NutrientGroup(
                title: 'Fats & Lipids',
                expanded: _expanded['Fats & Lipids']!,
                onToggle: () => setState(
                  () =>
                      _expanded['Fats & Lipids'] = !_expanded['Fats & Lipids']!,
                ),
                rows: _fatRows(totals),
              ),

              _NutrientGroup(
                title: 'Minerals',
                expanded: _expanded['Minerals']!,
                onToggle: () => setState(
                  () => _expanded['Minerals'] = !_expanded['Minerals']!,
                ),
                rows: _mineralRows(totals),
              ),

              _NutrientGroup(
                title: 'Vitamins',
                expanded: _expanded['Vitamins']!,
                onToggle: () => setState(
                  () => _expanded['Vitamins'] = !_expanded['Vitamins']!,
                ),
                rows: _vitaminRows(totals),
              ),

              _NutrientGroup(
                title: 'Other',
                expanded: _expanded['Other']!,
                onToggle: () =>
                    setState(() => _expanded['Other'] = !_expanded['Other']!),
                rows: _otherRows(totals),
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Row builders ───────────────────────────────────────────────────────

  List<_NutrientRow> _macroRows(
    NutrientTotals t,
    double calTarget,
    Map<String, double> macros,
  ) {
    final c = C0Theme.of(context);
    return [
      _NutrientRow(
        'Calories',
        t.calories.toDouble(),
        calTarget,
        'kcal',
        c.primary,
      ),
      _NutrientRow(
        'Protein',
        t.protein,
        macros['protein'] ?? 50,
        'g',
        const Color(0xFF3B82F6),
      ),
      _NutrientRow(
        'Carbs',
        t.carbs,
        macros['carbs'] ?? 275,
        'g',
        const Color(0xFFF59E0B),
      ),
      _NutrientRow(
        'Net Carbs',
        t.netCarbs,
        (macros['carbs'] ?? 275) - _DRV.fiber,
        'g',
        const Color(0xFFD97706),
      ),
      _NutrientRow('Fiber', t.fiber, _DRV.fiber, 'g', const Color(0xFF10B981)),
      _NutrientRow('Sugar', t.sugar, _DRV.sugar, 'g', const Color(0xFFEC4899)),
      _NutrientRow(
        'Added Sugar',
        t.addedSugar,
        _DRV.addedSugar,
        'g',
        const Color(0xFFDB2777),
      ),
      _NutrientRow(
        'Fat',
        t.fat,
        macros['fat'] ?? 78,
        'g',
        const Color(0xFF6B7280),
      ),
    ];
  }

  List<_NutrientRow> _fatRows(NutrientTotals t) => [
    _NutrientRow(
      'Saturated Fat',
      t.saturatedFat,
      _DRV.saturatedFat,
      'g',
      const Color(0xFFEF4444),
    ),
    _NutrientRow(
      'Trans Fat',
      t.transFat,
      _DRV.transFat,
      'g',
      const Color(0xFFDC2626),
      invertWarning: true,
    ),
    _NutrientRow(
      'Unsaturated Fat',
      t.unsatFat,
      40,
      'g',
      const Color(0xFF059669),
    ),
    _NutrientRow('Omega-3', t.omega3, 1.6, 'g', const Color(0xFF0EA5E9)),
    _NutrientRow('Omega-6', t.omega6, 17, 'g', const Color(0xFF7C3AED)),
    _NutrientRow(
      'Cholesterol',
      t.cholesterol,
      _DRV.cholesterol,
      'mg',
      const Color(0xFFF97316),
    ),
  ];

  List<_NutrientRow> _mineralRows(NutrientTotals t) => [
    _NutrientRow(
      'Sodium',
      t.sodium,
      _DRV.sodium,
      'mg',
      const Color(0xFF6366F1),
    ),
    _NutrientRow(
      'Potassium',
      t.potassium,
      _DRV.potassium,
      'mg',
      const Color(0xFF8B5CF6),
    ),
    _NutrientRow(
      'Calcium',
      t.calcium,
      _DRV.calcium,
      'mg',
      const Color(0xFF14B8A6),
    ),
    _NutrientRow('Iron', t.iron, _DRV.iron, 'mg', const Color(0xFFF87171)),
    _NutrientRow(
      'Magnesium',
      t.magnesium,
      _DRV.magnesium,
      'mg',
      const Color(0xFF34D399),
    ),
    _NutrientRow('Zinc', t.zinc, _DRV.zinc, 'mg', const Color(0xFFFBBF24)),
    _NutrientRow(
      'Phosphorus',
      t.phosphorus,
      _DRV.phosphorus,
      'mg',
      const Color(0xFF60A5FA),
    ),
    _NutrientRow(
      'Selenium',
      t.selenium,
      _DRV.selenium,
      'µg',
      const Color(0xFFA78BFA),
    ),
  ];

  List<_NutrientRow> _vitaminRows(NutrientTotals t) => [
    _NutrientRow(
      'Vitamin A',
      t.vitaminA,
      _DRV.vitaminA,
      'µg',
      const Color(0xFFF59E0B),
    ),
    _NutrientRow(
      'Vitamin B1',
      t.vitaminB1,
      _DRV.vitaminB1,
      'mg',
      const Color(0xFFFCD34D),
    ),
    _NutrientRow(
      'Vitamin B2',
      t.vitaminB2,
      _DRV.vitaminB2,
      'mg',
      const Color(0xFFFDE68A),
    ),
    _NutrientRow(
      'Vitamin B3',
      t.vitaminB3,
      _DRV.vitaminB3,
      'mg',
      const Color(0xFFD97706),
    ),
    _NutrientRow(
      'Vitamin B6',
      t.vitaminB6,
      _DRV.vitaminB6,
      'mg',
      const Color(0xFFB45309),
    ),
    _NutrientRow(
      'Vitamin B12',
      t.vitaminB12,
      _DRV.vitaminB12,
      'µg',
      const Color(0xFF92400E),
    ),
    _NutrientRow(
      'Vitamin C',
      t.vitaminC,
      _DRV.vitaminC,
      'mg',
      const Color(0xFFF97316),
    ),
    _NutrientRow(
      'Vitamin D',
      t.vitaminD,
      _DRV.vitaminD,
      'µg',
      const Color(0xFFEAB308),
    ),
    _NutrientRow(
      'Vitamin E',
      t.vitaminE,
      _DRV.vitaminE,
      'mg',
      const Color(0xFF84CC16),
    ),
    _NutrientRow(
      'Vitamin K',
      t.vitaminK,
      _DRV.vitaminK,
      'µg',
      const Color(0xFF22C55E),
    ),
    _NutrientRow(
      'Folate',
      t.folate,
      _DRV.folate,
      'µg',
      const Color(0xFF10B981),
    ),
  ];

  List<_NutrientRow> _otherRows(NutrientTotals t) => [
    _NutrientRow('Water', t.water, _DRV.water, 'ml', const Color(0xFF38BDF8)),
    _NutrientRow(
      'Caffeine',
      t.caffeine,
      _DRV.caffeine,
      'mg',
      const Color(0xFF78716C),
      invertWarning: true,
    ),
  ];
}

// ── Section header (summary bar) ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final NutrientTotals totals;
  const _SectionHeader({required this.totals});

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: c.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Nutrients',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const Spacer(),
          if (totals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'No food logged',
                style: AppTextStyles.micro.copyWith(color: c.textSecondary),
              ),
            )
          else
            Text(
              '${totals.logCount} item${totals.logCount != 1 ? 's' : ''}',
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

// ── Collapsible group ──────────────────────────────────────────────────────

class _NutrientGroup extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_NutrientRow> rows;
  final bool isLast;

  const _NutrientGroup({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.rows,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final trackedCount = rows.where((r) => r.value > 0).length;

    return Column(
      children: [
        // Group header
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: expanded ? c.primary : c.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (trackedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$trackedCount tracked',
                      style: AppTextStyles.micro.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Rows (animated)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: rows.map((r) => _NutrientRowWidget(row: r)).toList(),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        if (!isLast)
          Divider(height: 1, thickness: 1, color: C0Theme.of(context).divider),
      ],
    );
  }
}

// ── Row data class ─────────────────────────────────────────────────────────

class _NutrientRow {
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;
  final bool invertWarning; // true for nutrients where over-target = bad

  const _NutrientRow(
    this.label,
    this.value,
    this.target,
    this.unit,
    this.color, {
    this.invertWarning = false,
  });

  double get pct => target > 0 ? (value / target).clamp(0.0, 1.0) : 0;
  int get pctInt => (pct * 100).round();
  bool get isOver => value > target;
  bool get isGood => invertWarning ? !isOver : pct >= 0.9;
}

// ── Row widget ────────────────────────────────────────────────────────────

class _NutrientRowWidget extends StatelessWidget {
  final _NutrientRow row;
  const _NutrientRowWidget({required this.row});

  String _fmt(double v, String unit) {
    if (unit == 'kcal') return v.toInt().toString();
    if (v == 0) return '0';
    if (v < 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final pct = row.pct;
    final over = row.isOver && row.invertWarning;

    // Bar colour: green if good, amber if partial, red if inverted-over
    Color barColor;
    if (over) {
      barColor = const Color(0xFFEF4444);
    } else if (pct >= 0.9) {
      barColor = row.color;
    } else if (pct >= 0.5) {
      barColor = row.color.withValues(alpha: 0.75);
    } else {
      barColor = row.color.withValues(alpha: 0.5);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Colour dot
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: row.color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  row.label,
                  style: AppTextStyles.caption.copyWith(color: c.textPrimary),
                ),
              ),
              // Current value
              Text(
                '${_fmt(row.value, row.unit)} ${row.unit}',
                style: AppTextStyles.caption.copyWith(
                  color: over ? const Color(0xFFEF4444) : c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Percentage badge
              SizedBox(
                width: 40,
                child: Text(
                  row.target > 0 ? '${row.pctInt}%' : '—',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.micro.copyWith(
                    color: over
                        ? const Color(0xFFEF4444)
                        : pct >= 0.9
                        ? row.color
                        : c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: row.color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
