// TC001 – UC001 Register User
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cal0appv2/viewModels/viewauth/register_viewmodel.dart';
import '../mocks/mocks.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late RegisterViewModel vm;

  // Shared valid inputs
  const validName = 'Ahmad Faiz';
  const validEmail = 'faiz@example.com';
  const validPassword = 'secret123';
  const validGender = 'Male';
  const validGoal = 'Lose Weight';
  const validActivity = 'Moderate';
  final validBirthday = DateTime(2000, 1, 1);
  const validWeight = 70.0;
  const validHeight = 170.0;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    vm = RegisterViewModel(authRepository: mockAuthRepo);
  });

  // TC001_01 – Successful registration
  test('TC001_01: valid credentials → returns true and sets successMessage', () async {
    when(
      mockAuthRepo.register(
        userName: anyNamed('userName'),
        userEmail: anyNamed('userEmail'),
        userPassword: anyNamed('userPassword'),
        gender: anyNamed('gender'),
        goal: anyNamed('goal'),
        activityLevel: anyNamed('activityLevel'),
        birthday: anyNamed('birthday'),
        weight: anyNamed('weight'),
        height: anyNamed('height'),
      ),
    ).thenAnswer((_) async => 'uid_abc123');

    final result = await vm.register(
      userName: validName,
      userEmail: validEmail,
      userPassword: validPassword,
      confirmPassword: validPassword,
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isTrue);
    expect(vm.successMessage, equals('Account created successfully'));
    expect(vm.errorMessage, isNull);
  });

  // TC001_02 – Empty required fields
  test('TC001_02: empty fields → returns false with validation error', () async {
    final result = await vm.register(
      userName: '',
      userEmail: '',
      userPassword: '',
      confirmPassword: '',
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Please fill in all fields'));
    verifyNever(mockAuthRepo.register(
      userName: anyNamed('userName'),
      userEmail: anyNamed('userEmail'),
      userPassword: anyNamed('userPassword'),
      gender: anyNamed('gender'),
      goal: anyNamed('goal'),
      activityLevel: anyNamed('activityLevel'),
      birthday: anyNamed('birthday'),
      weight: anyNamed('weight'),
      height: anyNamed('height'),
    ));
  });

  // TC001_03 – Email already in use
  test('TC001_03: email already in use → returns false with friendly error', () async {
    when(
      mockAuthRepo.register(
        userName: anyNamed('userName'),
        userEmail: anyNamed('userEmail'),
        userPassword: anyNamed('userPassword'),
        gender: anyNamed('gender'),
        goal: anyNamed('goal'),
        activityLevel: anyNamed('activityLevel'),
        birthday: anyNamed('birthday'),
        weight: anyNamed('weight'),
        height: anyNamed('height'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'email-already-in-use'),
    );

    final result = await vm.register(
      userName: validName,
      userEmail: validEmail,
      userPassword: validPassword,
      confirmPassword: validPassword,
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isFalse);
    expect(
      vm.errorMessage,
      equals('An account with this email already exists.'),
    );
  });

  // TC001_04 – Invalid email format
  test('TC001_04: email without @ → returns false with format error', () async {
    final result = await vm.register(
      userName: validName,
      userEmail: 'notanemail',
      userPassword: validPassword,
      confirmPassword: validPassword,
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Invalid email format'));
  });

  // TC001_05 – Mismatched passwords
  test('TC001_05: passwords do not match → returns false', () async {
    final result = await vm.register(
      userName: validName,
      userEmail: validEmail,
      userPassword: validPassword,
      confirmPassword: 'different123',
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Passwords do not match'));
  });

  // TC001_06 – Password too short
  test('TC001_06: password shorter than 6 chars → returns false', () async {
    final result = await vm.register(
      userName: validName,
      userEmail: validEmail,
      userPassword: '123',
      confirmPassword: '123',
      gender: validGender,
      goal: validGoal,
      activityLevel: validActivity,
      birthday: validBirthday,
      weight: validWeight,
      height: validHeight,
    );

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Password must be at least 6 characters'));
  });
}
