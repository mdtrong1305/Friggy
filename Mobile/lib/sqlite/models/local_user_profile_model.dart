class LocalUserProfileModel {
  final String id; // user ID từ API
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl; // URL ảnh đại diện từ server
  final String? avatarLocalPath; // đường dẫn ảnh local (nếu upload chưa xong)
  final String? dateOfBirth;
  final String? gender;
  final String? bio;
  final String? role;
  final String? status;
  final int updatedAt;
  final String syncStatus; // 'synced' | 'pending'

  LocalUserProfileModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.avatarLocalPath,
    this.dateOfBirth,
    this.gender,
    this.bio,
    this.role,
    this.status,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'avatar_local_path': avatarLocalPath,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'bio': bio,
      'role': role,
      'status': status,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  factory LocalUserProfileModel.fromMap(Map<String, dynamic> map) {
    return LocalUserProfileModel(
      id: map['id'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      avatarLocalPath: map['avatar_local_path'] as String?,
      dateOfBirth: map['date_of_birth'] as String?,
      gender: map['gender'] as String?,
      bio: map['bio'] as String?,
      role: map['role'] as String?,
      status: map['status'] as String?,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  LocalUserProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? avatarLocalPath,
    String? dateOfBirth,
    String? gender,
    String? bio,
    String? syncStatus,
  }) {
    return LocalUserProfileModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      role: role,
      status: status,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
