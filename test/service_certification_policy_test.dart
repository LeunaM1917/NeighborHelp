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

  test(
    'all services require a certificate; unsupported tasks have no exemption',
    () {
      expect(
        serviceRequiresCertification(
          category: 'Cleaning',
          serviceTitle: 'House Cleaning',
        ),
        isTrue,
      );
      expect(
        serviceRequiresCertification(
          category: 'Tutoring',
          serviceTitle: 'Math Tutoring',
        ),
        isTrue,
      );
      expect(
        serviceRequiresCertification(
          category: 'Custom Services',
          serviceTitle: 'Birthday Setup',
        ),
        isTrue,
      );
    },
  );

  test('ordinary repair tasks also require a matching certificate', () {
    expect(
      serviceRequiresCertification(
        category: 'Home Repair',
        serviceTitle: 'Door Repair',
      ),
      isTrue,
    );
  });
}
