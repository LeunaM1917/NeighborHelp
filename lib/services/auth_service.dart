import 'provider_onboarding.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/functions_config.dart';
import 'account_setup_coordinator.dart';
import 'firestore_service.dart';
import 'push_notification_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_oauth.dart';
import '../constants/collections.dart';
import '../models/account_status.dart';
import '../models/user_role.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Shared across all `AuthService()` instances so Google sign-out works after any screen signs in.
  static GoogleSignIn? _sharedGoogleSignIn;
  static final _accountSetup = AccountSetupCoordinator();

  /// Compatibility for legacy admin page constructors; local admin sessions no longer exist.
  bool get isLocalAdminOnly => false;

  GoogleSignIn _gsi() {
    if (!isGoogleOAuthConfigured) {
      throw StateError(
        'Google Sign-In is not configured. Set kGoogleWebOAuthClientId in '
        'lib/config/google_oauth.dart (Web client ID from Firebase → Authentication → Google).',
      );
    }
    // `profile` triggers the Google People API from the plugin; `openid` + `email` is enough
    // for an ID token + Firebase `signInWithCredential`. Name/photo come from Firebase `User`
    // when present on the credential.
    // Web: only [clientId] is allowed; [serverClientId] must be null (google_sign_in_web asserts).
    // Android/iOS: [serverClientId] must be the Firebase **Web** OAuth client ID for an ID token.
    return _sharedGoogleSignIn ??= GoogleSignIn(
      scopes: const ['openid', 'email'],
      clientId: kIsWeb ? kGoogleWebOAuthClientId : null,
      serverClientId: kIsWeb ? null : kGoogleWebOAuthClientId,
    );
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges().asyncMap((
    user,
  ) async {
    await _accountSetup.waitUntilReady();
    // A failed setup can sign out before its queued sign-in event is delivered.
    return _auth.currentUser?.uid == user?.uid ? user : null;
  });

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) => _accountSetup.run(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      await _repairUserProfileIfMissing(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    }
    return cred;
  });

  /// Creates `users/{uid}` when Firebase Auth exists but the user doc was never
  /// written or was deleted. Uses `serviceProviders/{uid}` to infer Provider role.
  ///
  /// Returns `true` if a profile exists or was repaired; `false` if this session
  /// has already signed out or switched accounts.
  Future<bool> repairUserProfileIfMissing({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    await _accountSetup.waitUntilReady();
    if (_auth.currentUser?.uid != uid) return false;
    return _repairUserProfileIfMissing(
      uid: uid,
      email: email,
      displayName: displayName,
    );
  }

  Future<bool> _repairUserProfileIfMissing({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    final existing = await userRef.get();
    if (existing.exists && existing.data() != null) return true;

    var providerSnap = await _firestore
        .collection(FirestoreCollections.serviceProviders)
        .doc(uid)
        .get();

    final hasProvider = providerSnap.exists;
    final role = hasProvider ? UserRole.provider : UserRole.customer;
    final now = Timestamp.now();
    final resolvedEmail = email?.trim() ?? '';
    final fullName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (resolvedEmail.isNotEmpty ? resolvedEmail.split('@').first : 'User');

    await userRef.set({
      'fullName': fullName,
      'email': resolvedEmail,
      'contactNumber': null,
      'country': null,
      'marketingOptIn': false,
      'role': role.firestoreValue,
      'profilePhotoUrl': null,
      'address': null,
      'location': null,
      'accountStatus': AccountStatus.active.firestoreValue,
      'createdAt': now,
      'updatedAt': now,
      'lastActive': now,
    });

    final providerAtUid = _firestore
        .collection(FirestoreCollections.serviceProviders)
        .doc(uid);
    final providerAtUidSnap = await providerAtUid.get();

    if (hasProvider &&
        !providerAtUidSnap.exists &&
        providerSnap.data() != null) {
      await providerAtUid.set({
        ...providerSnap.data()!,
        'userId': uid,
        'updatedAt': now,
      });
    } else if (role == UserRole.provider && !providerAtUidSnap.exists) {
      await providerAtUid.set({
        'userId': uid,
        'bio': '',
        'serviceArea': '',
        'location': null,
        'serviceRadiusKm': 5,
        'averageRating': 0,
        'completedBookings': 0,
        'acceptedBookings': 0,
        'isVerified': false,
        'verificationStatus': 'Pending',
        'diditStatus': '',
        'diditSessionId': '',
        'verificationProvider': '',
        'governmentIdTypeCode': '',
        'governmentIdTypeLabel': '',
        'createdAt': now,
        'updatedAt': now,
      });
    }

    return true;
  }

  /// Sends a Firebase password-reset email to [email].
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Google Sign-In. [registrationRole] is used only when creating a new `users/{uid}` doc
  /// (sign-up flow). For log-in, pass `null` — new accounts default to **Customer**.
  ///
  /// **Web:** uses [FirebaseAuth.signInWithPopup] so OAuth runs through Firebase’s handler
  /// (`*.firebaseapp.com`). That avoids `origin_mismatch` from `google_sign_in_web` / GIS when
  /// localhost origins are finicky. **Mobile:** uses `google_sign_in` + ID token as before.
  Future<UserCredential> signInWithGoogle({UserRole? registrationRole}) =>
      _accountSetup.run(
        () => _signInWithGoogle(registrationRole: registrationRole),
      );

  Future<UserCredential> _signInWithGoogle({UserRole? registrationRole}) async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.setCustomParameters(const {'prompt': 'select_account'});
      try {
        final userCred = await _auth.signInWithPopup(provider);
        final user = userCred.user;
        if (user == null) {
          throw FirebaseAuthException(
            code: 'null-user',
            message: 'Sign-in failed.',
          );
        }
        try {
          await _ensureUserDocumentAfterGoogle(
            user: user,
            googleDisplayName: user.displayName,
            googlePhotoUrl: user.photoURL,
            registrationRole: registrationRole,
          );
        } catch (_) {
          await _auth.signOut();
          rethrow;
        }
        return userCred;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          throw FirebaseAuthException(
            code: 'aborted-by-user',
            message: 'Google sign-in was cancelled.',
          );
        }
        rethrow;
      } catch (e) {
        final s = e.toString();
        if (s.contains('API key not valid') ||
            (s.contains('INVALID_ARGUMENT') && s.contains('API key'))) {
          throw FirebaseAuthException(
            code: 'invalid-api-key',
            message:
                'Google rejected the Firebase Web API key (apiKey in lib/firebase_options.dart). '
                'In Google Cloud → Credentials, open the Browser key with that value. Under API restrictions, '
                'do not limit the key to Maps only: use “Don’t restrict key” for development, or allow '
                'Identity Toolkit API and other Firebase client APIs. Maps uses the separate key in web/index.html.',
          );
        }
        rethrow;
      }
    }

    final gsi = _gsi();
    final account = await gsi.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message:
            'Google did not return an ID token, which Firebase needs to sign you in. '
            'Android: use the Web client ID in kGoogleWebOAuthClientId and add your app SHA-1 '
            'under Firebase project settings → Your apps.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Sign-in failed.',
      );
    }

    try {
      await _ensureUserDocumentAfterGoogle(
        user: user,
        googleDisplayName: account.displayName ?? user.displayName,
        googlePhotoUrl: account.photoUrl ?? user.photoURL,
        registrationRole: registrationRole,
      );
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    return userCred;
  }

  Future<void> _ensureUserDocumentAfterGoogle({
    required User user,
    required String? googleDisplayName,
    required String? googlePhotoUrl,
    UserRole? registrationRole,
  }) async {
    final ref = _firestore.collection(FirestoreCollections.users).doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.data() ?? {};
      final storedRole = UserRole.fromFirestore(data['role']?.toString());
      final providerRef = _firestore
          .collection(FirestoreCollections.serviceProviders)
          .doc(user.uid);
      final providerSnap = await providerRef.get();
      final hasProviderProfile = providerSnap.exists;

      final updates = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (googlePhotoUrl != null &&
            ((data['profilePhotoUrl'] as String?)?.isEmpty ?? true))
          'profilePhotoUrl': googlePhotoUrl,
      };

      final effectiveRole = UserRole.resolve(
        storedRole: storedRole,
        hasProviderProfile: hasProviderProfile,
      );
      if (storedRole != UserRole.customer &&
          effectiveRole == UserRole.provider &&
          storedRole != UserRole.provider) {
        updates['role'] = UserRole.provider.firestoreValue;
      }

      if (data['accountStatus'] == 'Active') await ref.update(updates);

      if (effectiveRole == UserRole.provider && !hasProviderProfile) {
        final now = Timestamp.now();
        await providerRef.set({
          'userId': user.uid,
          'bio': '',
          'serviceArea': '',
          'location': null,
          'serviceRadiusKm': 5,
          'averageRating': 0,
          'completedBookings': 0,
          'acceptedBookings': 0,
          'isVerified': false,
          'verificationStatus': 'Pending',
          'diditStatus': '',
          'diditSessionId': '',
          'verificationProvider': '',
          'governmentIdTypeCode': '',
          'governmentIdTypeLabel': '',
          'createdAt': now,
          'updatedAt': now,
        });
      }
      return;
    }

    final email = user.email ?? '';
    final fullName = (googleDisplayName?.trim().isNotEmpty == true)
        ? googleDisplayName!.trim()
        : (email.isNotEmpty ? email.split('@').first : 'User');
    final role = registrationRole ?? UserRole.customer;
    final now = Timestamp.now();

    await ref.set({
      'fullName': fullName,
      'email': email,
      'contactNumber': null,
      'country': null,
      'marketingOptIn': false,
      'role': role.firestoreValue,
      'profilePhotoUrl': googlePhotoUrl,
      'address': null,
      'location': null,
      'accountStatus': AccountStatus.active.firestoreValue,
      'createdAt': now,
      'updatedAt': now,
      'lastActive': now,
    });

    if (role == UserRole.provider) {
      await _firestore
          .collection(FirestoreCollections.serviceProviders)
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'bio': '',
            'serviceArea': '',
            'location': null,
            'serviceRadiusKm': 5,
            'averageRating': 0,
            'completedBookings': 0,
            'acceptedBookings': 0,
            'isVerified': false,
            'verificationStatus': 'Pending',
            'diditStatus': '',
            'diditSessionId': '',
            'verificationProvider': '',
            'governmentIdTypeCode': '',
            'governmentIdTypeLabel': '',
            'createdAt': now,
            'updatedAt': now,
          });
    }

    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(fullName);
    }
    if (role == UserRole.provider) ProviderOnboarding.mark(user.uid);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? contactNumber,
    String? country,
    bool marketingOptIn = false,
  }) => _accountSetup.run(() async {
    if (role != UserRole.customer && role != UserRole.provider) {
      throw ArgumentError.value(role, 'role');
    }
    UserCredential? credential;
    FirebaseAuthException? existingAccountError;
    try {
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        // A previous attempt may have created Auth but failed to save its profile.
        // Prove ownership with the submitted password before resuming that attempt.
        existingAccountError = error;
        credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      final uid = credential.user!.uid;
      final now = Timestamp.now();
      final userDoc = _firestore
          .collection(FirestoreCollections.users)
          .doc(uid);
      final existing = await userDoc.get();
      final providerDoc = _firestore
          .collection(FirestoreCollections.serviceProviders)
          .doc(uid);
      if (existing.exists) {
        // Registration must never overwrite an established role or private profile.
        final data = existing.data()!;
        final providerMissing =
            role == UserRole.provider && !(await providerDoc.get()).exists;
        if (data['role'] != role.firestoreValue ||
            data['accountStatus'] != AccountStatus.active.firestoreValue ||
            !providerMissing) {
          throw existingAccountError ??
              FirebaseAuthException(code: 'email-already-in-use');
        }
      } else {
        await userDoc.set({
          'fullName': fullName,
          'email': email,
          'contactNumber': contactNumber,
          'country': country,
          'marketingOptIn': marketingOptIn,
          'role': role.firestoreValue,
          'profilePhotoUrl': null,
          'address': null,
          'location': null,
          'accountStatus': AccountStatus.active.firestoreValue,
          'createdAt': now,
          'updatedAt': now,
          'lastActive': now,
        });
      }
      if (role == UserRole.provider && !(await providerDoc.get()).exists) {
        await providerDoc.set({
          'userId': uid,
          'bio': '',
          'serviceArea': '',
          'location': null,
          'serviceRadiusKm': 5,
          'averageRating': 0,
          'completedBookings': 0,
          'acceptedBookings': 0,
          'isVerified': false,
          'verificationStatus': 'Pending',
          'diditStatus': '',
          'diditSessionId': '',
          'verificationProvider': '',
          'governmentIdTypeCode': '',
          'governmentIdTypeLabel': '',
          'createdAt': now,
          'updatedAt': now,
        });
      }
      await credential.user!.updateDisplayName(fullName);
      if (role == UserRole.provider) ProviderOnboarding.mark(uid);
      return credential;
    } catch (_) {
      // Keep RootGate from recovering a half-created provider as a customer.
      if (credential != null) await _auth.signOut();
      rethrow;
    }
  });

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      try {
        await FirebaseFunctions.instanceFor(
              region: kNeighborHelpFunctionsRegion,
            )
            .httpsCallable('recordSessionEvent')
            .call({'action': 'logout'})
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    try {
      await PushNotificationService().unregister().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {}
    try {
      await _sharedGoogleSignIn?.signOut();
    } catch (_) {
      // Ignore if Google was never used.
    }
    await _auth.signOut();
    await FirestoreService().clearSession();
  }

  static const _invalidApiKeyHelp =
      'Firebase rejected the Web API key in lib/firebase_options.dart. Fix: (1) Firebase Console → '
      'Project settings → Your apps → Web app → copy the API key and paste it as web.apiKey. '
      '(2) Google Cloud → Credentials → “Browser key (auto created by Firebase)” with that same key: '
      'under API restrictions use “Don’t restrict key” for dev, or allow Identity Toolkit API. '
      'If you use Website restrictions, add http://localhost:YOUR_PORT/* (and 127.0.0.1). '
      'Maps uses only the key in web/index.html — do not put the Maps key in firebase_options.';

  static bool _isInvalidApiKeyError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    return code.contains('api-key-not-valid') ||
        code.contains('invalid-api-key') ||
        msg.contains('api key not valid') ||
        msg.contains('invalid api key');
  }

  /// Short message for SnackBars / inline alerts (avoids empty or useless "Error" from the web SDK).
  static String messageForUser(Object error) {
    if (error is FirebaseAuthException) {
      if (_isInvalidApiKeyError(error)) {
        return _invalidApiKeyHelp;
      }
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty && msg.toLowerCase() != 'error') {
        return msg;
      }
      return switch (error.code) {
        'invalid-api-key' => _invalidApiKeyHelp,
        'aborted-by-user' => 'Cancelled.',
        _ => 'Sign-in failed (${error.code}).',
      };
    }
    if (error is FirebaseException) {
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
      return error.code;
    }
    final raw = error.toString();
    if (raw.isEmpty || raw == 'Error' || raw == 'Exception: Error') {
      return 'Something went wrong. Open the browser console (F12 → Console) for details.';
    }
    return raw;
  }
}
