class RegisterRequest {
  final String name;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String role;
  final String status;
  final bool verify;
  final String? notificationToken;
  final String? avatar;
  final String? miniAvatar;
  final int tokenVersion;

  RegisterRequest({
    required this.name,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    this.role = 'student',
    this.status = 'active',
    this.verify = false,
    this.notificationToken,
    this.avatar,
    this.miniAvatar,
    this.tokenVersion = 0,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      name: json['name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? 'student',
      status: json['status'] ?? 'active',
      verify: json['verify'] ?? false,
      notificationToken: json['notification_token'],
      avatar: json['avatar'],
      miniAvatar: json['mini_avatar'],
      tokenVersion: json['token_version'] ?? 0,
    );
  }

  List<String> validate() {
    List<String> errors = [];
    if (name.isEmpty || name.length < 1 || name.length > 250) {
      errors.add('Name must be between 1 and 250 characters');
    }
    if (lastName.isEmpty || lastName.length < 1 || lastName.length > 250) {
      errors.add('Last name must be between 1 and 250 characters');
    }
    if (username.isEmpty || username.length < 3 || username.length > 50) {
      errors.add('Username must be between 3 and 50 characters');
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      errors.add('Valid email is required');
    }
    if (password.isEmpty || password.length < 4) {
      errors.add('Password must be at least 4 characters');
    }
    if (!['student', 'teacher', 'admin'].contains(role)) {
      errors.add('Role must be student, teacher, or admin');
    }
    if (!['active', 'inactive', 'banned'].contains(status)) {
      errors.add('Status must be active, inactive, or banned');
    }
    return errors;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
