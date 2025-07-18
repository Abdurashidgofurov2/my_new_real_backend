import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import '../service/user_db.dart';
import '../service/jwt_service.dart';
import '../user/request/register_request.dart';
import '../models/login_model/login_model.dart';

import 'dart:io';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class AuthController {
  static Future<Response> register(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) return _badRequest('Request body is required');

      final data = jsonDecode(body);
      final registerRequest = RegisterRequest.fromJson(data);

      final errors = registerRequest.validate();
      if (errors.isNotEmpty) return _badRequest('Validation failed', details: errors);

      if (await UserDatabaseService.emailExists(registerRequest.email)) {
        return _badRequest('Email already exists');
      }
      if (await UserDatabaseService.usernameExists(registerRequest.username)) {
        return _badRequest('Username already exists');
      }

      final user = await UserDatabaseService.createUser(registerRequest);
      final tokenPair = JwtService.generateTokenPair(user);

      return Response.ok(jsonEncode({
        'success': true,
        'message': 'User registered successfully',
        'user': user.toJson(),
        'tokens': tokenPair.toJson(),
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Future<Response> login(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) return _badRequest('Request body is required');

      final data = jsonDecode(body);
      final loginRequest = LoginRequest.fromJson(data);

      final user = await UserDatabaseService.findUserByEmail(loginRequest.email);
      if (user == null) return _badRequest('User not found');

      if (!UserDatabaseService.verifyPassword(loginRequest.password, user.password)) {
        return _badRequest('Invalid password');
      }

      // TokenVersion ni oshirish
      await UserDatabaseService.incrementTokenVersion(user.uuid);
      final updatedUser = await UserDatabaseService.getUserDetails(user.uuid);
      final tokenPair = JwtService.generateTokenPair(updatedUser!);

      return Response.ok(jsonEncode({
        'success': true,
        'message': 'Login successful',
        'user': updatedUser.toJson(),
        'tokens': tokenPair.toJson(),
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Future<Response> checkUsername(Request request) async {
    try {
      final body = await request.readAsString();
      final data = body.isNotEmpty ? jsonDecode(body) : <String, dynamic>{};
      final username = data['username'] ?? request.url.queryParameters['username'];
      if (username == null || username.isEmpty) {
        return _badRequest('Username is required');
      }
      final exists = await UserDatabaseService.usernameExists(username);
      return Response.ok(jsonEncode({'exists': exists}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Future<Response> getUserDetails(Request request, String uuid) async {
    if (!await _checkAuth(request)) {
      return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});
    }
    try {
      final user = await UserDatabaseService.getUserDetails(uuid);
      if (user == null) return _badRequest('User not found');
      return Response.ok(jsonEncode({'user': user.toJson()}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Future<Response> updateUser(Request request, String uuid) async {
    if (!await _checkAuth(request)) {
      return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});
    }
    try {
      final contentType = request.headers['content-type'];
      if (contentType != null && contentType.contains('multipart/form-data')) {
        final boundary = contentType.split('boundary=')[1];
        final transformer = MimeMultipartTransformer(boundary);
        final parts = await transformer.bind(request.read()).toList();

        String? avatarPath;
        String? miniAvatarPath;
        Map<String, String> fields = {};

        for (final part in parts) {
          final contentDisposition = part.headers['content-disposition'];
          final nameMatch = RegExp(r'name="([^"]*)"').firstMatch(contentDisposition!);
          final filenameMatch = RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);

          final fieldName = nameMatch?.group(1);

          if (filenameMatch != null && fieldName != null) {
            final filename = filenameMatch.group(1)!;
            final ext = p.extension(filename);
            final saveDir = Directory('uploads/avatars');
            if (!saveDir.existsSync()) {
              saveDir.createSync(recursive: true);
            }
            final saveName = '${DateTime.now().millisecondsSinceEpoch}_$fieldName$ext';
            final savePath = p.join(saveDir.path, saveName);
            final file = File(savePath);
            await file.create(recursive: true);
            await part.pipe(file.openWrite());

            if (fieldName == 'avatar') avatarPath = savePath;
            if (fieldName == 'mini_avatar') miniAvatarPath = savePath;
          } else if (fieldName != null) {
            final value = await utf8.decoder.bind(part).join();
            fields[fieldName] = value;
          }
        }

        final updateRequest = RegisterRequest(
          name: fields['name'] ?? '',
          lastName: fields['last_name'] ?? '',
          username: fields['username'] ?? '',
          email: fields['email'] ?? '',
          password: fields['password'] ?? '',
          role: fields['role'] ?? 'student',
          status: fields['status'] ?? 'active',
          verify: fields['verify'] == 'true',
          notificationToken: fields['notification_token'],
          avatar: avatarPath,
          miniAvatar: miniAvatarPath,
        );
        final errors = updateRequest.validate();
        if (errors.isNotEmpty) return _badRequest('Validation failed', details: errors);
        await UserDatabaseService.updateUser(uuid, updateRequest);
        final user = await UserDatabaseService.getUserDetails(uuid);
        return Response.ok(jsonEncode({'success': true, 'user': user?.toJson()}), headers: {'Content-Type': 'application/json'});
      } else {
        final body = await request.readAsString();
        if (body.isEmpty) return _badRequest('Request body is required');
        final data = jsonDecode(body);
        final updateRequest = RegisterRequest.fromJson(data);
        final errors = updateRequest.validate();
        if (errors.isNotEmpty) return _badRequest('Validation failed', details: errors);
        await UserDatabaseService.updateUser(uuid, updateRequest);
        final user = await UserDatabaseService.getUserDetails(uuid);
        return Response.ok(jsonEncode({'success': true, 'user': user?.toJson()}), headers: {'Content-Type': 'application/json'});
      }
    } catch (e, st) {
      print('ERROR: $e\n$st');
      return _serverError(e);
    }
  }

  static Future<Response> updateUserFields(Request request, String uuid) async {
    if (!await _checkAuth(request)) {
      return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});
    }
    try {
      final body = await request.readAsString();
      if (body.isEmpty) return _badRequest('Request body is required');
      final data = jsonDecode(body) as Map<String, dynamic>;
      await UserDatabaseService.updateUserFields(uuid, data);
      final user = await UserDatabaseService.getUserDetails(uuid);
      return Response.ok(jsonEncode({'success': true, 'user': user?.toJson()}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Future<Response> deleteUser(Request request, String uuid) async {
    if (!await _checkAuth(request)) {
      return Response.forbidden(jsonEncode({'error': 'Unauthorized'}), headers: {'Content-Type': 'application/json'});
    }
    try {
      await UserDatabaseService.deleteUser(uuid);
      return Response.ok(jsonEncode({'success': true, 'message': 'User deleted'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _serverError(e);
    }
  }

  static Response _badRequest(String message, {List<String>? details}) => Response.badRequest(
    body: jsonEncode({'error': message, if (details != null) 'details': details}),
    headers: {'Content-Type': 'application/json'},
  );

  static Response _serverError(Object e) => Response.internalServerError(
    body: jsonEncode({'error': 'Internal server error', 'message': e.toString()}),
    headers: {'Content-Type': 'application/json'},
  );

  static Future<bool> _checkAuth(Request request) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) return false;
    final token = authHeader.substring(7);
    try {

      final jwt = JWT.verify(token, SecretKey("your-secret-key-here-change-in-production"));
      final userId = jwt.payload['user_id'];
      final tokenVersion = jwt.payload['token_version'];
      if (userId == null || tokenVersion == null) return false;
      final currentVersion = await UserDatabaseService.getTokenVersion(userId);
      return currentVersion == tokenVersion;
    } catch (_) {
      return false;
    }
  }
}