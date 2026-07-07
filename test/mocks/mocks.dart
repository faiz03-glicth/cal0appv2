import 'package:mockito/annotations.dart';
import 'package:cal0appv2/repositories/auth_repository.dart';
import 'package:cal0appv2/repositories/user_repository.dart';
import 'package:cal0appv2/repositories/foodlog_repository.dart';
import 'package:cal0appv2/repositories/off_food_repository.dart';

@GenerateMocks([
  AuthRepository,
  UserRepository,
  FoodLogRepository,
  OFFFoodRepository,
])
void main() {}
