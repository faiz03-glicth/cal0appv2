// lib/viewModels/foodlog/food_history_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:cal0appv2/models/logging/foodlog_model.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';

enum HistoryFilter { all, manual, scanned }

class FoodHistoryViewModel extends ChangeNotifier {
  final FoodLogRepository _repo;
  FoodHistoryViewModel({FoodLogRepository? repo})
    : _repo = repo ?? FoodLogRepository();

  List<FoodLogModel> _all = [];
  bool isLoading = false;
  String? errorMessage;
  HistoryFilter activeFilter = HistoryFilter.all;
  String searchQuery = '';

  List<FoodLogModel> get filtered {
    var list = _all;

    // Filter by source
    if (activeFilter == HistoryFilter.manual) {
      list = list.where((l) => l.isManual).toList();
    } else if (activeFilter == HistoryFilter.scanned) {
      list = list.where((l) => l.isScanned).toList();
    }

    // Search
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((l) => l.foodLogName.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  int get totalScanned => _all.where((l) => l.isScanned).length;
  int get totalManual => _all.where((l) => l.isManual).length;

  Future<void> load(String uid) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _all = await _repo.getAllFoodLogs(uid);
    } catch (e) {
      errorMessage = 'Failed to load history: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  void setFilter(HistoryFilter f) {
    activeFilter = f;
    notifyListeners();
  }

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  Future<void> delete(String uid, String id) async {
    await _repo.deleteFoodLog(uid, id);
    _all.removeWhere((l) => l.foodLogID == id);
    notifyListeners();
  }

  Future<void> update(String uid, FoodLogModel log) async {
    await _repo.updateFoodLog(uid, log);
    final i = _all.indexWhere((l) => l.foodLogID == log.foodLogID);
    if (i != -1) _all[i] = log;
    notifyListeners();
  }
}
