class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.phone,
    required this.isActive,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String roleLabel;
  final String phone;
  final bool isActive;
  final bool isPrimary;

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? roleLabel,
    String? phone,
    bool? isActive,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      roleLabel: roleLabel ?? this.roleLabel,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role_label': roleLabel,
        'phone': phone,
        'is_active': isActive,
        'is_primary': isPrimary,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      roleLabel: (json['role_label'] ?? 'Keluarga').toString(),
      phone: (json['phone'] ?? '').toString(),
      isActive: json['is_active'] as bool? ?? true,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}
