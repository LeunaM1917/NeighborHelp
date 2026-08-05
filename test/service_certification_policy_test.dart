import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/service_certification_policy.dart';

void main() {
  test('technical category requires certificate', () {
    expect(
      serviceRequiresCertification(
        category: 'Repair and Technical Services',
        serviceTitle: 'TV Repair',
      ),
      isTrue,
    );
  });

  test('electrical title requires certificate even under Home Repair', () {
    expect(
      serviceRequiresCertification(
        category: 'Home Repair',
        serviceTitle: 'Minor Electrical Help',
      ),
      isTrue,
    );
  });

  test('soft services do not require certificate', () {
    expect(
      serviceRequiresCertification(
        category: 'Cleaning',
        serviceTitle: 'House Cleaning',
      ),
      isFalse,
    );
    expect(
      serviceRequiresCertification(
        category: 'Tutoring',
        serviceTitle: 'Math Tutoring',
      ),
      isFalse,
    );
    expect(
      serviceRequiresCertification(
        category: 'Custom Services',
        serviceTitle: 'Birthday Setup',
      ),
      isFalse,
    );
  });

  test('ordinary home repair titles do not require certificate', () {
    expect(
      serviceRequiresCertification(
        category: 'Home Repair',
        serviceTitle: 'Door Repair',
      ),
      isFalse,
    );
  });
}
