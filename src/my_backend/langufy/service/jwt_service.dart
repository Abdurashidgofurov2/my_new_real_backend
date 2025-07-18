
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/token_model/token_model.dart';
import '../user/model/user_model.dart';

class JwtService {
  static const String _secretKey = 'your-secret-key-here-change-in-production';

  static TokenPair generateTokenPair(UserModel user) {
    final now = DateTime.now();
    final accessTokenExpiry = now.add(Duration(days: 7)); // 1 hafta
    final refreshTokenExpiry = now.add(Duration(days: 30)); // 1 oy

    // Access token payload
    final accessPayload = {
      'user_id': user.uuid,
      'email': user.email,
      'role': user.role,
      'type': 'access',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': accessTokenExpiry.millisecondsSinceEpoch ~/ 1000,
      'token_version': user.tokenVersion,
    };

    // Refresh token payload
    final refreshPayload = {
      'user_id': user.uuid,
      'type': 'refresh',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': refreshTokenExpiry.millisecondsSinceEpoch ~/ 1000,
      'token_version': user.tokenVersion,
    };

    final accessToken = JWT(accessPayload).sign(SecretKey(_secretKey));
    final refreshToken = JWT(refreshPayload).sign(SecretKey(_secretKey));

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiry,
      refreshTokenExpiresAt: refreshTokenExpiry,
    );
  }

  static void verifyToken(String token, {required int currentTokenVersion}) {
    final jwt = JWT.verify(token, SecretKey(_secretKey));
    final tokenVersion = jwt.payload['token_version'];
    if (tokenVersion == null || tokenVersion != currentTokenVersion) {
      // throw JWTExpiredError('Token is no longer valid (tokenVersion mismatch)');
    }
  }
}