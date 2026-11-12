// SDK interface fakes keep the account setup race deterministic without a server.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/user_role.dart';
import 'package:neighbor_help/services/auth_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'signup';
  @override
  String get email => 'signup@example.test';
  @override
  String? displayName;
  @override
  String? get photoURL => null;
  @override
  Future<void> updateDisplayName(String? value) async => displayName = value;
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
}

class _Auth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast(sync: true);
  final user = _User();
  bool alreadyExists = false;
  bool wrongPassword = false;
  int passwordChecks = 0;
  @override
  User? currentUser;
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (alreadyExists) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    currentUser = user;
    events.add(user);
    return _Credential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    passwordChecks++;
    if (wrongPassword) throw FirebaseAuthException(code: 'invalid-credential');
    currentUser = user;
    events.add(user);
    return _Credential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    events.add(null);
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    currentUser = user;
    events.add(user);
    return _Credential(user);
  }
}

class _Store extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  bool failWrite = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/$path');
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    await Future<void>.delayed(Duration.zero);
    return _Snapshot(store.docs[path]);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (store.failWrite) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    // Replacing a recovered profile would change protected registration fields.
    if (store.docs.containsKey(path)) {
      throw StateError('Existing profile overwritten');
    }
    store.docs[path] = Map.of(data);
    store.writes.add(path);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.docs[path]!.addAll(data.cast<String, dynamic>());
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

void main() {
  late _Auth auth;
  late _Store store;
  late AuthService signup;
  late AuthService root;
  setUp(() {
    auth = _Auth();
    store = _Store();
    signup = AuthService(auth: auth, firestore: store);
    root = AuthService(auth: auth, firestore: store);
  });
  tearDown(() async => auth.events.close());

  Future<UserCredential> register(UserRole role) => signup.register(
    email: 'signup@example.test',
    password: 'emulator-password',
    fullName: 'Test Signup',
    role: role,
    country: 'Philippines',
    marketingOptIn: true,
  );

  for (final role in [UserRole.customer, UserRole.provider]) {
    if (kIsWeb) {
      test(
        'Google ${role.name} signup also waits for its selected role profile',
        () async {
          Future<bool>? recovery;
          final raw = auth.events.stream.listen((user) {
            if (user != null) {
              recovery = root.repairUserProfileIfMissing(uid: user.uid);
            }
          });
          final session = root.authStateChanges().first;
          await signup.signInWithGoogle(registrationRole: role);
          expect(await recovery, isTrue);
          expect((await session)?.uid, 'signup');
          expect(store.docs['users/signup']!['role'], role.firestoreValue);
          expect(
            store.docs.containsKey('serviceProviders/signup'),
            role == UserRole.provider,
          );
          expect(store.writes.where((p) => p == 'users/signup'), hasLength(1));
          await raw.cancel();
        },
      );
    }
    test(
      '${role.name} registration finishes before root recovery and session consumers',
      () async {
        Future<bool>? recovery;
        final raw = auth.events.stream.listen((user) {
          if (user != null) {
            recovery = root.repairUserProfileIfMissing(
              uid: user.uid,
              email: user.email,
            );
          }
        });
        final session = root.authStateChanges().first;
        await register(role);
        expect(await recovery, isTrue);
        expect((await session)?.uid, 'signup');
        expect(store.docs['users/signup']!['role'], role.firestoreValue);
        expect(store.docs['users/signup']!['country'], 'Philippines');
        expect(store.docs['users/signup']!['marketingOptIn'], isTrue);
        expect(store.writes.where((p) => p == 'users/signup'), hasLength(1));
        expect(
          store.docs.containsKey('serviceProviders/signup'),
          role == UserRole.provider,
        );
        await raw.cancel();
      },
    );

    test(
      '${role.name} signup can resume an Auth-only account after password verification',
      () async {
        auth.alreadyExists = true;
        await register(role);
        expect(auth.passwordChecks, 1);
        expect(store.docs['users/signup']!['role'], role.firestoreValue);
      },
    );
  }

  test(
    'unfinished provider setup preserves its existing user profile',
    () async {
      auth.alreadyExists = true;
      store.docs['users/signup'] = {
        'role': 'Provider',
        'accountStatus': 'Active',
        'fullName': 'Original Name',
      };
      await register(UserRole.provider);
      expect(store.docs['users/signup']!['fullName'], 'Original Name');
      expect(store.writes, ['serviceProviders/signup']);
    },
  );

  test(
    'registration cannot replace a completed account or change its role',
    () async {
      auth.alreadyExists = true;
      store.docs['users/signup'] = {
        'role': 'Customer',
        'accountStatus': 'Active',
      };
      for (final role in [UserRole.customer, UserRole.provider]) {
        await expectLater(
          register(role),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'email-already-in-use',
            ),
          ),
        );
        expect(store.writes, isEmpty);
        expect(auth.currentUser, isNull);
      }
    },
  );

  test('wrong password cannot resume an existing account', () async {
    auth.alreadyExists = true;
    auth.wrongPassword = true;
    await expectLater(
      register(UserRole.provider),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(store.writes, isEmpty);
  });

  test(
    'failed profile write signs out before session consumers are released; retry succeeds',
    () async {
      store.failWrite = true;
      final session = root.authStateChanges().first;
      await expectLater(
        register(UserRole.provider),
        throwsA(isA<FirebaseException>()),
      );
      expect(await session, isNull);
      expect(auth.currentUser, isNull);
      store.failWrite = false;
      auth.alreadyExists = true;
      await register(UserRole.provider);
      expect(store.docs['users/signup']!['role'], 'Provider');
    },
  );
}
