import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';

/// Attach this to ANY edit screen's State to get "edit a field → the
/// Authentic/Non-Authentic verdict re-checks itself" for free, without
/// re-implementing the debounce/listener wiring each time.
///
/// Usage in a State class:
/// ```dart
/// class _MyEditSheetState extends State<MyEditSheet>
///     with AuthenticityReanalysisMixin {
///   late final TextEditingController _ingredientText;
///
///   @override
///   String get ingredientTextForReanalysis => _ingredientText.text;
///
///   @override
///   void onAuthenticityChecked(AuthenticityCheck result) {
///     setState(() => _lastCheck = result);
///   }
///
///   @override
///   void initState() {
///     super.initState();
///     _ingredientText = TextEditingController(text: initialText);
///     watchFieldsForReanalysis([_ingredientText, _calories, _protein, ...]);
///     runReanalysisNow(); // show a result immediately, don't wait for an edit
///   }
///
///   @override
///   void dispose() {
///     disposeAuthenticityReanalysis();
///     super.dispose();
///   }
/// }
/// ```
mixin AuthenticityReanalysisMixin<T extends StatefulWidget> on State<T> {
  Timer? _reanalysisDebounce;
  final List<TextEditingController> _watchedControllers = [];

  /// The current ingredient text to run the check against. Implementers
  /// return whatever controller/field holds their ingredient list.
  String get ingredientTextForReanalysis;

  /// Called whenever a check completes (debounced edit, or a manual
  /// [runReanalysisNow] call). Implementers update their own UI state here.
  void onAuthenticityChecked(AuthenticityCheck result);

  /// Call once, e.g. in initState, after creating the controllers you want
  /// to watch — nutrient fields AND the ingredient text field. Editing ANY
  /// of them schedules a re-check.
  void watchFieldsForReanalysis(List<TextEditingController> controllers) {
    _watchedControllers.addAll(controllers);
    for (final c in controllers) {
      c.addListener(_onWatchedFieldChanged);
    }
  }

  void _onWatchedFieldChanged() => scheduleReanalysis();

  /// Debounces then runs the check. Called automatically by watched-field
  /// listeners; can also be called manually if needed.
  void scheduleReanalysis({
    Duration delay = const Duration(milliseconds: 450),
  }) {
    _reanalysisDebounce?.cancel();
    _reanalysisDebounce = Timer(delay, runReanalysisNow);
  }

  /// Runs the deterministic nitrogen-compound check immediately (no
  /// debounce). Safe to call as soon as ingredient text exists, so the
  /// verdict never sits on "Unknown" waiting for an edit that may never
  /// come.
  void runReanalysisNow() {
    if (!mounted) return;
    final text = ingredientTextForReanalysis;
    if (text.trim().isEmpty) return;
    onAuthenticityChecked(IngredientAuthenticityService.check(text));
  }

  /// Call from dispose().
  void disposeAuthenticityReanalysis() {
    _reanalysisDebounce?.cancel();
    for (final c in _watchedControllers) {
      c.removeListener(_onWatchedFieldChanged);
    }
    _watchedControllers.clear();
  }
}
