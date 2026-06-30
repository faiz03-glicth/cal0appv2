import 'package:flutter/material.dart';
import 'package:cal0appv2/models/report_model.dart';
import 'package:cal0appv2/repositories/report_repository.dart';

class ReportViewModel extends ChangeNotifier {
  final ReportRepository _repo;

  ReportViewModel({ReportRepository? repo})
    : _repo = repo ?? ReportRepository();

  List<ReportModel> _myReports = [];
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  String? successMessage;

  List<ReportModel> get myReports => List.unmodifiable(_myReports);
  bool get hasReports => _myReports.isNotEmpty;

  // ── Submit a report ──────────────────────────────────────────────────────

  Future<void> submitReport({
    required String userId,
    required String reportDetails,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (userId.isEmpty) {
        errorMessage = 'You must be logged in to submit a report.';
        isSubmitting = false;
        notifyListeners();
        return;
      }
      if (reportDetails.trim().isEmpty) {
        errorMessage = 'Please describe the issue before submitting.';
        isSubmitting = false;
        notifyListeners();
        return;
      }

      await _repo.submitReport(
        userId: userId,
        reportDetails: reportDetails.trim(),
      );
      successMessage = 'Report submitted. Thank you for letting us know.';

      // Refresh the local list so it shows up immediately if the user
      // navigates to "My Reports" right after submitting.
      await loadMyReports(userId);
    } catch (e) {
      errorMessage = 'Failed to submit report: $e';
    }

    isSubmitting = false;
    notifyListeners();
  }

  // ── View own report history ─────────────────────────────────────────────

  Future<void> loadMyReports(String userId) async {
    if (userId.isEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _myReports = await _repo.getReportsForUser(userId);
    } catch (e) {
      errorMessage = 'Failed to load your reports: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  void clearForLogout() {
    _myReports = [];
    isLoading = false;
    isSubmitting = false;
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
