// TC004 – UC004 Forgot Password
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cal0appv2/viewModels/viewauth/forgot_password_viewmodel.dart';
import '../mocks/mocks.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late ForgotPasswordViewModel vm;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    vm = ForgotPasswordViewModel(authRepository: mockAuthRepo);
  });

  // TC004_01 – Valid email → reset email sent
  test('TC004_01: valid email → sends reset email and sets emailSent=true', () async {
    when(mockAuthRepo.sendPasswordResetEmail('faiz@example.com'))
        .thenAnswer((_) async {});

    final result = await vm.sendResetEmail('faiz@example.com');

    expect(result, isTrue);
    expect(vm.emailSent, isTrue);
    expect(vm.successMessage, contains('faiz@example.com'));
    expect(vm.errorMessage, isNull);
  });

  // TC004_02 – Invalid / empty email
  test('TC004_02: email without @ → returns false with validation error', () async {
    final result = await vm.sendResetEmail('notanemail');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Please enter a valid email address'));
    expect(vm.emailSent, isFalse);
    verifyNever(mockAuthRepo.sendPasswordResetEmail(any));
  });

  // TC004_03 – Empty email string
  test('TC004_03: empty email → returns false', () async {
    final result = await vm.sendResetEmail('');

    expect(result, isFalse);
    expect(vm.errorMessage, isNotNull);
  });

  // TC004_04 – User not found on Firebase
  test('TC004_04: user-not-found → returns false with friendly message', () async {
    when(mockAuthRepo.sendPasswordResetEmail(any))
        .thenThrow(FirebaseAuthException(code: 'user-not-found'));

    final result = await vm.sendResetEmail('ghost@example.com');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('No account found with this email address.'));
  });
}
