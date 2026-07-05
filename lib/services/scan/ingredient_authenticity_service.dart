// lib/services/scan/ingredient_authenticity_service.dart
//
// PROVENANCE NOTE:
// This file's design is ported from an already-existing, more mature
// version found on the `main` branch (same class shape, same
// isNitrogenCompound distinction). It is NOT a blind copy — `main`'s
// version was written against a more advanced food_detail_view.dart
// that does not yet exist on ScannerIntegration, so this version is
// wired only to what ScannerIntegration currently has: ScanViewModel's
// inline `_ingredientDatabase` / `_detectIngredients` / `DetectedIngredient`.
//
// WHY THIS EXISTS:
// ScanViewModel currently keeps its own private copy of the ingredient
// database and its own detection function inline. Extracting it here:
//   1. Makes the rule-based detector independently unit-testable.
//   2. Gives ScannerIntegration a single source of truth BEFORE any
//      future merge from `main` — so when main's richer
//      food_detail_view.dart does get ported over, it can consume this
//      same service instead of re-introducing a second private copy
//      (which is exactly the bug main's version was created to fix).
//   3. Separates two genuinely different authenticity mechanisms that
//      your project runs in parallel:
//        - The ONNX DistilBERT classifier: probabilistic verdict,
//          Authentic / Spiked / Plant-Based, with a confidence score.
//        - This rule-based nitrogen-compound check: deterministic,
//          binary Authentic / Non-Authentic, used to sanity-check and
//          explain the ML verdict (see hasConfirmedSpikingAgent below,
//          used by ScanViewModel to downgrade an ML "Spiked" verdict to
//          low-confidence if no nitrogen compound was actually found).
//
// Behaviour is unchanged from the original inline version in
// ScanViewModel — this is a lift-and-shift, not a re-tuning of the
// matching logic or the ingredient list itself.

class IngredientRule {
  final String name; // display name
  final String category; // e.g. 'Amino Spiking Agent'
  final String explanation; // plain-English why this matters
  final List<String> aliases; // OCR variant spellings to match
  final bool isNitrogenCompound; // true = counts toward Non-Authentic verdict

  const IngredientRule({
    required this.name,
    required this.category,
    required this.explanation,
    required this.aliases,
    this.isNitrogenCompound = false,
  });
}

class DetectedIngredient {
  final String name;
  final String category;
  final String explanation;
  final bool isAmSpiking; // kept as `isAmSpiking` to match existing call
  // sites (scan_confirm_sheet.dart, whey_verdict_card.dart-style widgets)
  // that already read `.isAmSpiking` — avoids a rename ripple.

  const DetectedIngredient({
    required this.name,
    required this.category,
    required this.explanation,
    required this.isAmSpiking,
  });
}

enum NitrogenCheckVerdict { authentic, nonAuthentic }

/// Result of the deterministic nitrogen-compound check. Always exactly
/// Authentic or Non-Authentic — this is NOT the ML confidence score.
class AuthenticityCheck {
  final NitrogenCheckVerdict verdict;
  final String ingredientText;
  final List<DetectedIngredient> allDetected;
  final List<DetectedIngredient> nitrogenFlags;

  const AuthenticityCheck({
    required this.verdict,
    required this.ingredientText,
    required this.allDetected,
    required this.nitrogenFlags,
  });

  bool get isAuthentic => verdict == NitrogenCheckVerdict.authentic;
  bool get isNonAuthentic => verdict == NitrogenCheckVerdict.nonAuthentic;
}

class IngredientAuthenticityService {
  IngredientAuthenticityService._();

  // ── Known "special" ingredient database ─────────────────────────────
  // Lifted verbatim from the original ScanViewModel._ingredientDatabase.
  static const List<IngredientRule> database = <IngredientRule>[
    // ── Amino spiking agents ────────────────────────────────────────────
    IngredientRule(
      name: 'Glycine',
      category: 'Amino Spiking Agent',
      explanation:
          'Cheap amino acid sometimes added to inflate protein content on lab tests. '
          'Does not provide the same muscle-building benefit as whey.',
      aliases: ['glycine'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Taurine',
      category: 'Amino Spiking Agent',
      explanation:
          'Free-form amino acid that registers as protein on Kjeldahl/Dumas tests '
          'but is not a complete protein source and does not contribute to MPS.',
      aliases: ['taurine'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Creatine Monohydrate',
      category: 'Performance Compound / Potential Spiking Agent',
      explanation:
          'Creatine contains nitrogen and can inflate total protein readings. '
          'It is a legitimate performance supplement, but its presence in a '
          '"protein powder" label may indicate label amino spiking.',
      aliases: [
        'creatine monohydrate',
        'creatine',
        'creatine hcl',
        'creatine ethyl',
      ],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Beta-Alanine',
      category: 'Amino Spiking Agent',
      explanation:
          'Non-essential amino acid that contributes nitrogen to protein tests '
          'without being a quality protein source.',
      aliases: ['beta-alanine', 'beta alanine', 'β-alanine'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'L-Glutamine',
      category: 'Amino Spiking Agent',
      explanation:
          'Free amino acid that is sometimes added in excess to boost nitrogen content. '
          'While it has some gut-health benefits, large amounts suggest spiking.',
      aliases: ['l-glutamine', 'glutamine', 'l glutamine'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Arginine',
      category: 'Amino Spiking Agent',
      explanation:
          'Free-form amino acid used to boost nitrogen scores. '
          'At high doses it is more indicative of spiking than a benefit.',
      aliases: ['arginine', 'l-arginine', 'l arginine', 'arginine akg'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Alanine',
      category: 'Amino Spiking Agent',
      explanation:
          'Cheap non-essential amino acid used to inflate protein readings.',
      aliases: ['alanine', 'l-alanine', 'l alanine'],
      isNitrogenCompound: true,
    ),
    IngredientRule(
      name: 'Leucine',
      category: 'Amino Spiking Agent / BCAA',
      explanation:
          'While leucine is a branched-chain amino acid with real benefit, '
          'excessive free-form leucine on a label can indicate spiking. '
          'It is expected inside whey protein but suspicious as a standalone addition.',
      aliases: ['leucine', 'l-leucine', 'l leucine'],
      isNitrogenCompound: true,
    ),

    // ── Artificial sweeteners (informational only — NOT nitrogen flags) ──
    IngredientRule(
      name: 'Sucralose',
      category: 'Artificial Sweetener',
      explanation:
          'Zero-calorie chlorinated sugar. Common in protein powders. '
          'Some consumers prefer to avoid it.',
      aliases: ['sucralose', 'splenda'],
    ),
    IngredientRule(
      name: 'Acesulfame Potassium',
      category: 'Artificial Sweetener',
      explanation:
          'Also listed as Ace-K or E950. Often used alongside sucralose. '
          'Some studies suggest possible gut microbiome effects.',
      aliases: [
        'acesulfame potassium',
        'acesulfame-k',
        'ace-k',
        'acesulfame k',
        'e950',
      ],
    ),
    IngredientRule(
      name: 'Aspartame',
      category: 'Artificial Sweetener',
      explanation:
          'Common artificial sweetener. Should be avoided by people with PKU.',
      aliases: ['aspartame', 'nutrasweet', 'equal'],
    ),

    // ── Fillers & thickeners (informational only) ────────────────────────
    IngredientRule(
      name: 'Maltodextrin',
      category: 'Filler / High GI Carbohydrate',
      explanation:
          'High-glycaemic carbohydrate often used as a filler or flavour carrier. '
          'Can contribute to blood sugar spikes.',
      aliases: ['maltodextrin'],
    ),
    IngredientRule(
      name: 'Soy Lecithin',
      category: 'Emulsifier',
      explanation:
          'Common emulsifier. Possible concern for those with soy allergies '
          'or those wanting to limit phytoestrogen sources.',
      aliases: ['soy lecithin', 'soya lecithin'],
    ),
  ];

  /// Every ingredient rule that matches [ingredientText] — sweeteners,
  /// fillers, and nitrogen compounds alike. This is what
  /// `_detectIngredients()` in ScanViewModel used to return directly.
  static List<DetectedIngredient> detectAll(String ingredientText) {
    if (ingredientText.isEmpty) return const [];
    final lower = ingredientText.toLowerCase();
    final found = <DetectedIngredient>[];
    for (final rule in database) {
      final matched = rule.aliases.any(lower.contains);
      if (matched) {
        found.add(
          DetectedIngredient(
            name: rule.name,
            category: rule.category,
            explanation: rule.explanation,
            isAmSpiking: rule.isNitrogenCompound,
          ),
        );
      }
    }
    return found;
  }

  /// True if at least one *confirmed nitrogen-based* ingredient (not a
  /// sweetener/filler) was found — this is what ScanViewModel uses to
  /// cross-check the ML verdict (downgrade to low-confidence if the model
  /// says "Spiked" but no nitrogen compound was actually detected).
  static bool hasConfirmedSpikingAgent(List<DetectedIngredient> detected) =>
      detected.any((d) => d.isAmSpiking);

  /// Optional: the full deterministic Authentic/Non-Authentic check,
  /// separate from (and complementary to) the ONNX ML verdict. Not
  /// currently wired into ScanViewModel's flow — provided here so you can
  /// adopt it explicitly if you want a labelled deterministic verdict
  /// alongside the ML one, matching the "Authenticity Detection Engine"
  /// described in your presentation slides.
  static AuthenticityCheck check(String ingredientText) {
    final trimmed = ingredientText.trim();
    final all = detectAll(trimmed);
    final nitrogenFlags = all.where((d) => d.isAmSpiking).toList();
    return AuthenticityCheck(
      verdict: nitrogenFlags.isNotEmpty
          ? NitrogenCheckVerdict.nonAuthentic
          : NitrogenCheckVerdict.authentic,
      ingredientText: trimmed,
      allDetected: all,
      nitrogenFlags: nitrogenFlags,
    );
  }
}
