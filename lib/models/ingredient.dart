/// One row of a container's ingredient list. [quantity] is free text (e.g.
/// "500g", "2 portions"), not a strict unit.
class Ingredient {
  const Ingredient({required this.name, required this.quantity});

  final String name;
  final String quantity;

  bool get hasName => name.trim().isNotEmpty;

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};

  Ingredient copyWith({String? name, String? quantity}) => Ingredient(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
      );

  @override
  bool operator ==(Object other) =>
      other is Ingredient && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);
}
