import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/services/scan/ingredient_authenticity_service.dart';

/// The one editable ingredient-list component with a pencil edit button,
/// used everywhere in the app that shows/edits an ingredient list
/// (live scan confirm sheet, food history edit sheet, anywhere else).
///
/// It doesn't run the re-check itself — pair it with a
/// [TextEditingController] that's already registered with
/// AuthenticityReanalysisMixin.watchFieldsForReanalysis(...) in the parent,
/// so every edit here flows through the same debounced re-check as every
/// other field.
class EditableIngredientField extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  const EditableIngredientField({
    super.key,
    required this.controller,
    this.title = 'Ingredient List',
  });

  @override
  State<EditableIngredientField> createState() =>
      _EditableIngredientFieldState();
}

class _EditableIngredientFieldState extends State<EditableIngredientField> {
  bool _expanded = true;
  bool _editing = false;

  void _startEditing() => setState(() {
    _editing = true;
    _expanded = true;
  });

  void _finishEditing() => setState(() => _editing = false);

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final items = widget.controller.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.length > 1)
        .toList();
    final nitrogenNames = IngredientAuthenticityService.database
        .where((r) => r.isNitrogenCompound)
        .expand((r) => r.aliases)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.list_alt_rounded, color: c.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.bodyCompact.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          _editing
                              ? 'Editing — tap Done when finished'
                              : '${items.isEmpty ? '?' : items.length} ingredients — tap to view',
                          style: AppTextStyles.micro.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_editing)
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: c.primary,
                      ),
                      tooltip: 'Edit ingredients',
                      onPressed: _startEditing,
                    )
                  else
                    TextButton(
                      onPressed: _finishEditing,
                      child: const Text('Done'),
                    ),
                  if (!_editing)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: c.textSecondary,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: (_expanded || _editing)
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _editing
                  ? TextField(
                      controller: widget.controller,
                      maxLines: 5,
                      minLines: 3,
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Whey Protein Isolate, Cocoa, Glycine, Sucralose',
                        hintStyle: TextStyle(
                          color: c.textSecondary.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: c.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: c.divider),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _finishEditing(),
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: items.map((ing) {
                        final isFlagged = nitrogenNames.any(
                          (k) => ing.toLowerCase().contains(k),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isFlagged
                                ? c.warning.withValues(alpha: 0.10)
                                : c.card,
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                            border: Border.all(
                              color: isFlagged
                                  ? c.warning.withValues(alpha: 0.4)
                                  : c.divider,
                            ),
                          ),
                          child: Text(
                            ing,
                            style: AppTextStyles.micro.copyWith(
                              color: isFlagged ? c.warning : c.textPrimary,
                              fontWeight: isFlagged
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}