import 'dart:io';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class UserModel {
  final String uuid;
  final String name;
  final String lastName;
  final String username;
  final String email;
  final String? avatar;
  final String? miniAvatar;
  final String role;
  final String status;
  final bool verify;
  final String password;
  final String? notificationToken;
  final int tokenVersion;

  UserModel({
    required this.uuid,
    required this.name,
    required this.lastName,
    required this.username,
    required this.email,
    this.avatar,
    this.miniAvatar,
    required this.role,
    required this.status,
    required this.verify,
    required this.password,
    this.notificationToken,
    this.tokenVersion = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'last_name': lastName,
      'username': username,
      'email': email,
      'avatar': avatar,
      'mini_avatar': miniAvatar,
      'role': role,
      'status': status,
      'verify': verify,
      'notification_token': notificationToken,
      'token_version': tokenVersion,
    };
  }
}