import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'controller/auth_controller.dart';
import 'service/user_db.dart';

Future<void> main() async {
  await UserDatabaseService.initialize();
  print('Database initialized.');

  final router = Router()
    ..post('/api/auth/register', AuthController.register)
    ..post('/api/auth/login', AuthController.login)
    ..post('/api/auth/check-username', AuthController.checkUsername)
    ..get('/api/user/<uuid>', AuthController.getUserDetails)
    ..put('/api/user/<uuid>', AuthController.updateUser)
    ..patch('/api/user/<uuid>', AuthController.updateUserFields)
    ..delete('/api/user/<uuid>', AuthController.deleteUser)
    ..get('/health', (Request request) => Response.ok(
      jsonEncode({'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    ));

  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(router);

  final server = await serve(handler, 'localhost', 8080);
  print('Server running at http://localhost:8080');

  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nShutting down server...');
    await server.close(force: true);
     UserDatabaseService.close();
    print('Server and database closed.');
    exit(0);
  });
}

class RegisterRequest {
  final String name;
  final String? lastName;
  final String username;
  final String email;
  final String password;
  final String? role;
  final String? status;
  final bool? verify;
  final String? notificationToken;
  final String? avatar;
  final String? miniAvatar;

  RegisterRequest({
    required this.name,
    this.lastName,
    required this.username,
    required this.email,
    required this.password,
    this.role,
    this.status,
    this.verify,
    this.notificationToken,
    this.avatar,
    this.miniAvatar,
  });

  // fromJson va validate metodlari ham shunga mos bo'lishi kerak
}