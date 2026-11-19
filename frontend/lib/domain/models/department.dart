final class Department {
  factory Department.fromJson(Map<String, Object?> json) => Department(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'slug': slug};

  Department copyWith({String? id, String? name, String? slug}) => Department(
    id: id ?? this.id,
    name: name ?? this.name,
    slug: slug ?? this.slug,
  );

  const Department({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;
}
