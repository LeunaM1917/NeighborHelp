import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/utils/service_certification_policy.dart';

void main() {
  test(
    'construction work needs a current matching administrator-approved certificate',
    () {
      ServiceProviderProfile profile(
        String qualification, {
        String status = 'Approved',
        String expiry = '2099-01-01',
        bool approved = true,
      }) => ServiceProviderProfile.fromFirestore('p', {
        'userId': 'p',
        'isVerified': true,
        'approvedCertificationIds': approved ? ['cert'] : <String>[],
        'certificationHistory': [
          {
            'id': 'cert',
            'name': qualification,
            'provider': 'TESDA',
            'status': status,
            'certificationId': 'TEST-NC-001',
            'url': 'gs://demo/certificates/p/cert/proof.pdf',
            'expirationDate': expiry,
            'issueDate': '2026-01-01',
            'reviewedBy': 'admin',
            'reviewedAt': Timestamp.now(),
            'verificationSource': 'TESDA Registry of Certified Workers',
          },
        ],
      });
      for (final row in [
        ('Masonry', 'Masonry NC II'),
        ('Concrete Block Laying', 'Masonry NC II'),
        ('Bricklaying', 'Masonry NC II'),
        ('Wall Plastering', 'Masonry NC II'),
        ('Construction Carpentry', 'Carpentry NC II'),
        ('Tile Installation', 'Tile Setting NC II'),
        ('Tile Repair', 'Tile Setting NC II'),
        ('Construction Painting', 'Construction Painting NC II'),
      ]) {
        bool matches(ServiceProviderProfile p) => hasMatchingServiceCertificate(
          p,
          category: 'Construction',
          serviceTitle: row.$1,
        );
        expect(matches(profile(row.$2)), isTrue, reason: row.$1);
        expect(
          matches(profile('Domestic Work NC II')),
          isFalse,
          reason: row.$1,
        );
        expect(
          matches(profile(row.$2, status: 'Pending')),
          isFalse,
          reason: row.$1,
        );
        expect(
          matches(profile(row.$2, expiry: '2000-01-01')),
          isFalse,
          reason: row.$1,
        );
        expect(
          matches(profile(row.$2, approved: false)),
          isFalse,
          reason: row.$1,
        );
      }
      expect(
        isSupportedService('Construction', 'General Construction'),
        isFalse,
      );
      expect(
        isSupportedService('Construction', 'Structural Engineering'),
        isFalse,
      );
    },
  );
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
