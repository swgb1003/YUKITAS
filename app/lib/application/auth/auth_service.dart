class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.isDemo = false,
  });

  final String id;
  final String? email;
  final String? displayName;
  final bool isDemo;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract interface class AuthService {
  bool get usesFirebase;
  AuthUser? get currentUser;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();
  Future<void> signOut();
}

class DemoAuthService implements AuthService {
  AuthUser? _currentUser;

  @override
  bool get usesFirebase => false;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _demoDelay();
    return _setDemoUser(email: email);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    await _demoDelay();
    return _setDemoUser(email: email);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    await _demoDelay();
    return _setDemoUser(email: 'demo@yukitas.jp', displayName: 'デモユーザー');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 420));

  AuthUser _setDemoUser({required String email, String? displayName}) {
    return _currentUser = AuthUser(
      id: 'demo-user',
      email: email.trim(),
      displayName: displayName,
      isDemo: true,
    );
  }
}
