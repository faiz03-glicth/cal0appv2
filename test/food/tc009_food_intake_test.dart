// TC009 – UC009 Log Food Intake
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cal0appv2/viewModels/foodlog/foodlog_viewmodel.dart';
import 'package:cal0appv2/models/foodlog_model.dart';
import '../mocks/mocks.mocks.dart';

void main() {
  late MockFoodLogRepository mockFoodLogRepo;
  late MockOFFFoodRepository mockOffRepo;
  late FoodLogViewModel vm;

  setUp(() {
    // Prevent SharedPreferences platform channel errors in unit tests
    SharedPreferences.setMockInitialValues({});
    mockFoodLogRepo = MockFoodLogRepository();
    mockOffRepo = MockOFFFoodRepository();
    vm = FoodLogViewModel(
      foodLogRepository: mockFoodLogRepo,
      foodRepository: mockOffRepo,
    );
  });

  // TC009_01 – Successful food log entry
  test('TC009_01: valid food name + calories → addFoodLog returns true', () async {
    when(mockFoodLogRepo.addFoodLog(any, any)).thenAnswer((_) async {});
    when(mockFoodLogRepo.getFoodLogs(any, any))
        .thenAnswer((_) async => <FoodLogModel>[]);

    vm.updateFoodName('Nasi Lemak');
    vm.updateCalories('450');

    final result = await vm.addFoodLog(uid: 'uid_001');

    expect(result, isTrue);
    expect(vm.errorMessage, isNull);
    verify(mockFoodLogRepo.addFoodLog('uid_001', any)).called(1);
  });

  // TC009_02 – Missing food name
  test('TC009_02: empty food name → addFoodLog returns false with error', () async {
    vm.updateFoodName('');
    vm.updateCalories('300');

    final result = await vm.addFoodLog(uid: 'uid_001');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Food name and calories are required'));
    verifyNever(mockFoodLogRepo.addFoodLog(any, any));
  });

  // TC009_03 – Missing calories
  test('TC009_03: empty calories → addFoodLog returns false with error', () async {
    vm.updateFoodName('Roti Canai');
    vm.updateCalories('');

    final result = await vm.addFoodLog(uid: 'uid_001');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Food name and calories are required'));
  });

  // TC009_04 – Food logs loaded from repository
  test('TC009_04: loadFoodLogs → populates foodLogs and computes hasLogs', () async {
    final logs = [
      FoodLogModel(
        foodLogID: 'log_1',
        userId: 'uid_001',
        foodLogName: 'Milo',
        calorieIntake: 150,
        foodLogDate: DateTime.now(),
        loggedAt: DateTime.now(),
      ),
    ];
    when(mockFoodLogRepo.getFoodLogs(any, any)).thenAnswer((_) async => logs);

    await vm.loadFoodLogs(uid: 'uid_001');

    expect(vm.foodLogs.length, equals(1));
    expect(vm.hasLogs, isTrue);
    expect(vm.totalCalories, equals(150));
  });

  // TC009_05 – Delete food log
  test('TC009_05: deleteFoodLog → removes entry and updates totals', () async {
    final log = FoodLogModel(
      foodLogID: 'log_1',
      userId: 'uid_001',
      foodLogName: 'Teh Tarik',
      calorieIntake: 120,
      foodLogDate: DateTime.now(),
      loggedAt: DateTime.now(),
    );
    when(mockFoodLogRepo.getFoodLogs(any, any))
        .thenAnswer((_) async => [log]);
    when(mockFoodLogRepo.deleteFoodLog('uid_001', 'log_1'))
        .thenAnswer((_) async {});

    await vm.loadFoodLogs(uid: 'uid_001');
    expect(vm.hasLogs, isTrue);

    await vm.deleteFoodLog(uid: 'uid_001', foodLogID: 'log_1');

    expect(vm.foodLogs, isEmpty);
    expect(vm.hasLogs, isFalse);
  });
}
