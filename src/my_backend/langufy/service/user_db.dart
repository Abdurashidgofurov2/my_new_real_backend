import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import '../user/model/user_model.dart';
import '../user/request/register_request.dart';

class UserDatabaseService {
  static late Database _db;

  static Future<void> initialize() async {
    final dbPath = Directory.current.path;
    final path = join(dbPath, 'users.db');
    _db = sqlite3.open(path);
    _createTable();
  }

  static void _createTable() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lastName TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        avatar TEXT,
        miniAvatar TEXT,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        verify INTEGER NOT NULL,
        password TEXT NOT NULL,
        notificationToken TEXT,
        tokenVersion INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> close() async => _db.dispose();

  static Future<bool> emailExists(String email) async =>
      _db.select('SELECT 1 FROM users WHERE email = ?', [email]).isNotEmpty;

  static Future<bool> usernameExists(String username) async =>
      _db.select('SELECT 1 FROM users WHERE username = ?', [username]).isNotEmpty;

  static Future<UserModel> createUser(RegisterRequest request) async {
    final uuid = const Uuid().v4();
    final user = UserModel(
      uuid: uuid,
      name: request.name,
      lastName: request.lastName,
      username: request.username,
      email: request.email,
      avatar: request.avatar,
      miniAvatar: request.miniAvatar,
      role: request.role,
      status: request.status,
      verify: request.verify,
      password: hashPassword(request.password),
      notificationToken: request.notificationToken,
      tokenVersion: 0,
    );
    _db.execute(
      'INSERT INTO users (uuid, name, lastName, username, email, avatar, miniAvatar, role, status, verify, password, notificationToken, tokenVersion) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        user.uuid, user.name, user.lastName, user.username, user.email,
        user.avatar, user.miniAvatar, user.role, user.status, user.verify ? 1 : 0,
        user.password, user.notificationToken, user.tokenVersion
      ],
    );
    return user;
  }

  static Future<UserModel?> findUserByEmail(String email) async {
    final result = _db.select('SELECT * FROM users WHERE email = ?', [email]);
    if (result.isEmpty) return null;
    return _fromMap(result.first);
  }

  static Future<UserModel?> findUserByUsername(String username) async {
    final result = _db.select('SELECT * FROM users WHERE username = ?', [username]);
    if (result.isEmpty) return null;
    return _fromMap(result.first);
  }

  static Future<UserModel?> getUserDetails(String uuid) async {
    final result = _db.select('SELECT * FROM users WHERE uuid = ?', [uuid]);
    if (result.isEmpty) return null;
    return _fromMap(result.first);
  }

  static Future<void> updateUser(String uuid, RegisterRequest request) async {
    _db.execute(
      'UPDATE users SET name = ?, lastName = ?, username = ?, email = ?, avatar = ?, miniAvatar = ?, role = ?, status = ?, verify = ?, password = ?, notificationToken = ?, tokenVersion = ? WHERE uuid = ?',
      [
        request.name, request.lastName, request.username, request.email,
        request.avatar, request.miniAvatar, request.role, request.status,
        request.verify ? 1 : 0, hashPassword(request.password), request.notificationToken, request.tokenVersion, uuid
      ],
    );
  }

  static Future<void> updateUserFields(String uuid, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    final keys = fields.keys.toList();
    final values = keys.map((k) => fields[k]).toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');
    _db.execute('UPDATE users SET $setClause WHERE uuid = ?', [...values, uuid]);
  }

  static Future<void> deleteUser(String uuid) async {
    _db.execute('DELETE FROM users WHERE uuid = ?', [uuid]);
  }

  static String hashPassword(String password) =>
      sha256.convert(password.codeUnits).toString();

  static bool verifyPassword(String password, String hash) =>
      hashPassword(password) == hash;

  static UserModel _fromMap(Map<String, Object?> userData) {
    return UserModel(
      uuid: userData['uuid'] as String,
      name: userData['name'] as String,
      lastName: userData['lastName'] as String,
      username: userData['username'] as String,
      email: userData['email'] as String,
      avatar: userData['avatar'] as String?,
      miniAvatar: userData['miniAvatar'] as String?,
      role: userData['role'] as String,
      status: userData['status'] as String,
      verify: (userData['verify'] as int) == 1,
      password: userData['password'] as String,
      notificationToken: userData['notificationToken'] as String?,
      tokenVersion: userData['tokenVersion'] is int ? userData['tokenVersion'] as int : 0,
    );
  }

  static Future<void> incrementTokenVersion(String uuid) async {
    _db.execute('UPDATE users SET tokenVersion = tokenVersion + 1 WHERE uuid = ?', [uuid]);
  }

  static Future<int> getTokenVersion(String uuid) async {
    final result = _db.select('SELECT tokenVersion FROM users WHERE uuid = ?', [uuid]);
    if (result.isEmpty) return 0;
    return result.first['tokenVersion'] as int;
  }
}