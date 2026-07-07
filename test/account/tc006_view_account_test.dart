// TC006 – UC006 View & Update Account / Password
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cal0appv2/viewModels/usermodel/user_viewmodel.dart';
import 'package:cal0appv2/models/user_model.dart';
import '../mocks/mocks.mocks.dart';

UserModel _makeUser() => UserModel(
      userId: 'uid_001',
      userName: 'Ahmad Faiz',
      userEmail: 'faiz@example.com',
      gender: 'Male',
      goal: 'Lose Weight',
      activityLevel: 'Moderate',
      weight: 75.0,
      height: 170.0,
      birthday: DateTime(2000, 6, 15),
    );

void main() {
  late MockUserRepository mockUserRepo;
  late MockAuthRepository mockAuthRepo;
  late UserViewModel vm;

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockAuthRepo = MockAuthRepository();
    vm = UserViewModel(
      userRepository: mockUserRepo,
      authRepository: mockAuthRepo,
    );
  });

  // TC006_01 – User data loaded correctly from repository
  test('TC006_01: loadUser → populates ViewModel fields from repository', () async {
    final user = _makeUser();
    when(mockUserRepo.getUser('uid_001')).thenAnswer((_) async => user);

    await vm.loadUser('uid_001');

    expect(vm.userName, equals('Ahmad Faiz'));
    expect(vm.userEmail, equals('faiz@example.com'));
    expect(vm.gender, equals('Male'));
    expect(vm.goal, equals('Lose Weight'));
    expect(vm.activityLevel, equals('Moderate'));
    expect(vm.weight, equals(75.0));
    expect(vm.height, equals(170.0));
    expect(vm.errorMessage, isNull);
  });

  // TC006_02 – No user document found returns null gracefully
  test('TC006_02: loadUser with unknown uid → user remains null', () async {
    when(mockUserRepo.getUser('uid_unknown')).thenAnswer((_) async => null);

    await vm.loadUser('uid_unknown');

    expect(vm.user, isNull);
    expect(vm.errorMessage, isNull);
  });

  // TC006_03 – Repository throws → error message set
  test('TC006_03: loadUser repo error → errorMessage set, isLoading=false', () async {
    when(mockUserRepo.getUser('uid_001'))
        .thenThrow(Exception('Firestore unavailable'));

    await vm.loadUser('uid_001');

    expect(vm.errorMessage, isNotNull);
    expect(vm.isLoading, isFalse);
  });

  // TC006_04 – Update password with valid new password
  test('TC006_04: valid new password → calls updatePassword on repo', () async {
    when(mockUserRepo.updatePassword('uid_001', 'newSecret1'))
        .thenAnswer((_) async {});

    await vm.updatePassword('uid_001', 'newSecret1');

    expect(vm.errorMessage, isNull);
    expect(vm.successMessage, equals('Password updated successfully'));
    verify(mockUserRepo.updatePassword('uid_001', 'newSecret1')).called(1);
  });

  // TC006_05 – Update password too short
  test('TC006_05: password < 6 chars → sets errorMessage, skips repo call', () async {
    await vm.updatePassword('uid_001', '123');

    expect(vm.errorMessage, equals('Password must be at least 6 characters'));
    verifyNever(mockUserRepo.updatePassword(any, any));
  });
}
