// TC002 – UC002 Login
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cal0appv2/viewModels/viewauth/auth_viewmodel.dart';
import '../mocks/mocks.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late AuthViewModel vm;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    vm = AuthViewModel(authRepository: mockAuthRepo);
  });

  // TC002_01 – Successful login
  test('TC002_01: valid credentials → returns true', () async {
    when(mockAuthRepo.signIn('faiz@example.com', 'secret123'))
        .thenAnswer((_) async => 'uid_abc');

    final result = await vm.signIn('faiz@example.com', 'secret123');

    expect(result, isTrue);
    expect(vm.errorMessage, isNull);
    expect(vm.isLoading, isFalse);
  });

  // TC002_02 – Wrong password
  test('TC002_02: wrong password → returns false with error message', () async {
    when(mockAuthRepo.signIn('faiz@example.com', 'wrongpw'))
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    final result = await vm.signIn('faiz@example.com', 'wrongpw');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Incorrect password. Please try again.'));
    expect(vm.isLoading, isFalse);
  });

  // TC002_03 – User not found
  test('TC002_03: unregistered email → returns false with user-not-found error', () async {
    when(mockAuthRepo.signIn('ghost@example.com', 'secret123'))
        .thenThrow(FirebaseAuthException(code: 'user-not-found'));

    final result = await vm.signIn('ghost@example.com', 'secret123');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('No account found with this email.'));
  });

  // TC002_04 – Generic failure
  test('TC002_04: network error → returns false with generic message', () async {
    when(mockAuthRepo.signIn(any, any)).thenThrow(Exception('timeout'));

    final result = await vm.signIn('faiz@example.com', 'secret123');

    expect(result, isFalse);
    expect(vm.errorMessage, equals('Sign in failed. Please try again.'));
  });
}
