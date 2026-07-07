// TC005 – UC005 Personalise User Profile
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

  // TC005_01 – Successful profile update
  test('TC005_01: valid profile data → updates user and sets successMessage', () async {
    final user = _makeUser();
    when(mockUserRepo.getUser('uid_001')).thenAnswer((_) async => user);
    when(mockUserRepo.updateUser(any)).thenAnswer((_) async {});

    await vm.loadUser('uid_001');

    await vm.updateProfile(
      userId: 'uid_001',
      userName: 'Faiz Updated',
      userEmail: 'faiz.updated@example.com',
      gender: 'Male',
      goal: 'Maintain Weight',
      activityLevel: 'Active',
      birthday: DateTime(2000, 6, 15),
      weight: 70.0,
      height: 172.0,
    );

    expect(vm.errorMessage, isNull);
    expect(vm.successMessage, equals('Profile updated successfully'));
    verify(mockUserRepo.updateUser(any)).called(1);
  });

  // TC005_02 – Invalid email in profile update
  test('TC005_02: invalid email → sets errorMessage, skips updateUser', () async {
    final user = _makeUser();
    when(mockUserRepo.getUser('uid_001')).thenAnswer((_) async => user);

    await vm.loadUser('uid_001');

    await vm.updateProfile(
      userId: 'uid_001',
      userName: 'Faiz',
      userEmail: 'bad-email',
      gender: 'Male',
      goal: 'Lose Weight',
      activityLevel: 'Moderate',
      birthday: DateTime(2000, 6, 15),
      weight: 75.0,
      height: 170.0,
    );

    expect(vm.errorMessage, equals('Invalid email format'));
    verifyNever(mockUserRepo.updateUser(any));
  });

  // TC005_03 – Update fails when no user loaded
  test('TC005_03: no user loaded → sets errorMessage about restart', () async {
    await vm.updateProfile(
      userId: 'uid_001',
      userName: 'Faiz',
      userEmail: 'faiz@example.com',
      gender: 'Male',
      goal: 'Lose Weight',
      activityLevel: 'Moderate',
      birthday: DateTime(2000, 6, 15),
      weight: 75.0,
      height: 170.0,
    );

    expect(vm.errorMessage, contains('No user data loaded'));
    verifyNever(mockUserRepo.updateUser(any));
  });
}
