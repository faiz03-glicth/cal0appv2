import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';
import 'package:cal0appv2/views/widgets/c0_app_bar.dart';
import 'package:cal0appv2/views/widgets/app_primary_button.dart';
import 'package:cal0appv2/views/widgets/app_message_banner.dart';
import 'package:cal0appv2/views/widgets/app_section_title.dart';
import 'package:cal0appv2/views/widgets/app_card.dart';
import 'package:cal0appv2/viewModels/usermodel/report_viewmodel.dart';
import 'package:cal0appv2/models/report_model.dart';

class ReportSubmissionView extends StatefulWidget {
  const ReportSubmissionView({super.key});

  @override
  State<ReportSubmissionView> createState() => _ReportSubmissionViewState();
}

class _ReportSubmissionViewState extends State<ReportSubmissionView> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty || !mounted) return;
      context.read<ReportViewModel>().loadMyReports(uid);
    });
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit(ReportViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await vm.submitReport(userId: uid, reportDetails: _details.text);
    if (vm.errorMessage == null && mounted) {
      _details.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final c = C0Theme.of(context);

    return Scaffold(
      appBar: const C0AppBar(title: 'Report a Problem', showBack: true),
      backgroundColor: c.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vm.errorMessage != null) ...[
                AppMessageBanner.error(message: vm.errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (vm.successMessage != null) ...[
                AppMessageBanner.success(message: vm.successMessage!),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Submit a new report ─────────────────────────────────
              const AppSectionTitle(title: 'Describe the Issue'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell us what went wrong — a scan result that looked '
                      'incorrect, a bug, or anything else you noticed. An '
                      'admin will review it.',
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _details,
                      minLines: 5,
                      maxLines: 8,
                      style: AppTextStyles.fieldText.copyWith(
                        color: c.textPrimary,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please describe the issue'
                          : null,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. "The whey label scan flagged a safe '
                            'product as Risk" or "App crashed when I logged food."',
                        hintStyle: AppTextStyles.fieldHint.copyWith(
                          color: c.textSecondary,
                        ),
                        filled: true,
                        fillColor: c.fieldFill,
                        contentPadding: const EdgeInsets.all(AppSpacing.lg),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: c.formBorder, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: c.primary, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: c.warning, width: 1),
                        ),
                        errorMaxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'Submit Report',
                icon: Icons.send,
                isLoading: vm.isSubmitting,
                onPressed: () => _submit(vm),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── Past reports ─────────────────────────────────────────
              const AppSectionTitle(title: 'My Reports'),
              if (vm.isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(color: c.primary),
                  ),
                )
              else if (!vm.hasReports)
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        color: c.textSecondary,
                        size: AppSizes.smallIconSize,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'You haven\u2019t submitted any reports yet.',
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...vm.myReports.map((r) => _ReportHistoryTile(report: r)),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Past report tile ────────────────────────────────────────────────────────

class _ReportHistoryTile extends StatelessWidget {
  final ReportModel report;
  const _ReportHistoryTile({required this.report});

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.report_outlined,
              color: c.primary,
              size: AppSizes.smallIconSize,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.reportDetails,
                    style: AppTextStyles.body.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatDate(report.timestamp),
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
