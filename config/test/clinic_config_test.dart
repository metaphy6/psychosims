import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  test('ClinicConfig exposes default clinic and routing constants', () {
    const config = ClinicConfig();
    expect(config.officeRentMicros, greaterThan(0));
    expect(config.chaosRollProbabilityMillis, lessThan(1000));
    expect(config.taxBrackets.length, greaterThanOrEqualTo(2));
  });
}
