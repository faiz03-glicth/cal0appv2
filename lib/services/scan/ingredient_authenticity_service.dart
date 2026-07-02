// Single source of truth for ingredient / nitrogen-spiking detection.
//
// Both the live scan flow (ScanViewModel) and food history
// (food_detail_view.dart) used to keep their own private copy of this
// ingredient database and their own detection function. That duplication
// is exactly what caused the two screens to drift and behave
// inconsistently. Everything that needs to answer "is this ingredient
// list Authentic or Non-Authentic" should go through
// [IngredientAuthenticityService.check] instead of reimplementing it.

class IngredientRule {
  final String name;
  final String category;
  final String explanation;
  final List<String> aliases;
  // Nitrogen-containing compounds that can distort protein/Kjeldahl-style
  // readings if free-formed into a supplement — this is what the
  // Authentic / Non-Authentic check flags on.
  final bool isNitrogenCompound;

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
  final bool isAmSpiking;

  const DetectedIngredient({
    required this.name,
    required this.category,
    required this.explanation,
    required this.isAmSpiking,
  });
}

enum NitrogenCheckVerdict { authentic, nonAuthentic }

/// Result of running [IngredientAuthenticityService.check] on a piece of
/// ingredient text. Deterministic and rule-based — not an ML confidence
/// score — so it's always exactly Authentic or Non-Authentic.
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

  static const List<IngredientRule> database = <IngredientRule>[
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
          'Free amino acid sometimes added in excess to boost nitrogen content. '
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
          'excessive free-form leucine on a label can indicate spiking.',
      aliases: ['leucine', 'l-leucine', 'l leucine'],
      isNitrogenCompound: true,
    ),
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
          'Also listed as Ace-K or E950. Often used alongside sucralose.',
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
    IngredientRule(
      name: 'Maltodextrin',
      category: 'Filler / High GI Carbohydrate',
      explanation:
          'High-glycaemic carbohydrate often used as a filler or flavour carrier.',
      aliases: ['maltodextrin'],
    ),
    IngredientRule(
      name: 'Soy Lecithin',
      category: 'Emulsifier',
      explanation:
          'Common emulsifier. Possible concern for those with soy allergies.',
      aliases: ['soy lecithin', 'soya lecithin'],
    ),
  ];

  /// Every ingredient rule that matches [ingredientText] (sweeteners,
  /// fillers, and nitrogen compounds alike). Used for the "Flagged
  /// Ingredients" panels.
  static List<DetectedIngredient> detectAll(String ingredientText) {
    if (ingredientText.isEmpty) return const [];
    final lower = ingredientText.toLowerCase();
    final found = <DetectedIngredient>[];
    for (final rule in database) {
      for (final alias in rule.aliases) {
        if (lower.contains(alias)) {
          found.add(
            DetectedIngredient(
              name: rule.name,
              category: rule.category,
              explanation: rule.explanation,
              isAmSpiking: rule.isNitrogenCompound,
            ),
          );
          break;
        }
      }
    }
    return found;
  }

  /// The single entry point for the Authentic / Non-Authentic check.
  /// Non-Authentic if any nitrogen-based spiking compound is present in
  /// [ingredientText], Authentic otherwise.
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
