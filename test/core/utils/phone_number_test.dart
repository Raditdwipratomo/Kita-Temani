import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/utils/phone_number.dart';

void main() {
  group('PhoneNumber', () {
    test('toInternational converts 08xx to 628xx', () {
      expect(PhoneNumber.toInternational('0857 1122 33'), '62857112233');
      expect(PhoneNumber.toInternational('0813-9876-5432'), '6281398765432');
    });

    test('formatDisplay formats phone numbers consistently', () {
      expect(PhoneNumber.formatDisplay('6281234567890'), '0812-3456-7890');
    });
  });
}
