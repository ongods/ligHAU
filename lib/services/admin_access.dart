/// Local prototype access only. Production authorization belongs on a backend.
class AdminAccess {
  static bool _authenticated = false;

  static bool get isAuthenticated => _authenticated;

  static bool signIn(String username, String password) {
    _authenticated = username == 'admin' && password == 'ligHAU-admin';
    return _authenticated;
  }

  static void signOut() => _authenticated = false;
}
