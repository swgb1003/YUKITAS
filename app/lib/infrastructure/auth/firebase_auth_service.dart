import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../application/auth/auth_service.dart';
import 'yukitas_firebase_options.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  Future<void>? _googleInitialization;

  @override
  bool get usesFirebase => true;

  @override
  AuthUser? get currentUser => _toAuthUser(_firebaseAuth.currentUser);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        final provider =
            GoogleAuthProvider()
              ..setCustomParameters(const {'prompt': 'select_account'});
        credential = await _firebaseAuth.signInWithPopup(provider);
      } else {
        await (_googleInitialization ??= GoogleSignIn.instance.initialize(
          serverClientId: YukitasFirebaseOptions.webClientId,
        ));
        if (!GoogleSignIn.instance.supportsAuthenticate()) {
          throw const AuthFailure(
            'この端末ではGoogleログインを利用できません。メールでログインしてください。',
            code: 'google-sign-in-unavailable',
          );
        }
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw const AuthFailure(
            'Googleから認証情報を取得できませんでした。',
            code: 'missing-google-id-token',
          );
        }
        credential = await _firebaseAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      return _requireUser(credential.user);
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    } catch (_) {
      throw const AuthFailure(
        'Googleログインを完了できませんでした。もう一度お試しください。',
        code: 'google-sign-in-failed',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out has already completed. Google may not be initialized.
      }
    }
  }

  AuthUser _requireUser(User? user) {
    final mapped = _toAuthUser(user);
    if (mapped == null) {
      throw const AuthFailure('認証したユーザー情報を取得できませんでした。', code: 'missing-user');
    }
    return mapped;
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  AuthFailure _mapFirebaseFailure(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-email' => 'メールアドレスの形式が正しくありません。',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'メールアドレスまたはパスワードが正しくありません。',
      'email-already-in-use' => 'このメールアドレスはすでに登録されています。',
      'weak-password' => 'より安全なパスワードを設定してください。',
      'user-disabled' => 'このアカウントは現在利用できません。',
      'too-many-requests' => '試行回数が多すぎます。少し時間をおいてお試しください。',
      'network-request-failed' => '通信を確認して、もう一度お試しください。',
      'popup-closed-by-user' => 'Googleログインがキャンセルされました。',
      'popup-blocked' => 'ログイン画面を開けませんでした。ポップアップを許可してください。',
      'operation-not-allowed' => 'このログイン方法はFirebase側でまだ有効になっていません。',
      'account-exists-with-different-credential' =>
        '同じメールアドレスが別のログイン方法で登録されています。',
      _ => 'ログインを完了できませんでした。もう一度お試しください。',
    };
    return AuthFailure(message, code: error.code);
  }
}
