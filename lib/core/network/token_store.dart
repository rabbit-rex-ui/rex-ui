abstract interface class TokenStore {
  String? get accessToken;
  String? get refreshToken;
  Future<void> save({required String accessToken, String? refreshToken});
  Future<void> clear();
}

class InMemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;
  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;
  @override
  Future<void> save({required String accessToken, String? refreshToken}) async {
    _access = accessToken;
    if (refreshToken != null) _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
