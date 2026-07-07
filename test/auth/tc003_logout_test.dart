// TC003 – UC003 Logout
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

  // TC003_01 – Sign-out calls repository
  test('TC003_01: signOut → delegates to repository signOut', () async {
    when(mockAuthRepo.signOut()).thenAnswer((_) async {});

    await vm.signOut();

    verify(mockAuthRepo.signOut()).called(1);
  });

  // TC003_02 – Sign-out callbacks are invoked
  test('TC003_02: signOut → invokes all registered sign-out callbacks', () async {
    when(mockAuthRepo.signOut()).thenAnswer((_) async {});

    bool callbackFired = false;
    vm.addSignOutCallback(() => callbackFired = true);

    await vm.signOut();

    expect(callbackFired, isTrue);
  });

  // TC003_03 – Multiple callbacks all fire
  test('TC003_03: multiple callbacks → all are invoked on signOut', () async {
    when(mockAuthRepo.signOut()).thenAnswer((_) async {});

    int count = 0;
    vm.addSignOutCallback(() => count++);
    vm.addSignOutCallback(() => count++);
    vm.addSignOutCallback(() => count++);

    await vm.signOut();

    expect(count, equals(3));
  });
}
