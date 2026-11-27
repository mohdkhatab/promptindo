import '../../../core/utils/value_utils.dart';

/// `categories/{categoryId}` entity. `icon` is an emoji string so the data
/// model stays platform-neutral (no code-point mapping table to drift).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.description,
    required this.promptCount,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final String description;
  final int promptCount;
  final int sortOrder;

  factory Category.fromMap(Map<String, dynamic> map, {String? id}) {
    return Category(
      id: asString(map['id'], id ?? ''),
      name: asString(map['name']),
      slug: asString(map['slug']),
      icon: asString(map['icon']),
      description: asString(map['description']),
      promptCount: asInt(map['prompt_count']),
      sortOrder: asInt(map['sort_order']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'slug': slug,
    'icon': icon,
    'description': description,
    'prompt_count': promptCount,
    'sort_order': sortOrder,
  };
}
