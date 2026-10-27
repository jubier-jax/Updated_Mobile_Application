
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String name;
  final String category;
  final String location;
  final String shopName;
  final String phone;
  final String description;
  final double price;
  final bool available;
  final String ownerId;
  final DateTime? createdAt;
  final int stock;

  ItemModel({
    this.id = '',
    required this.name,
    required this.category,
    required this.location,
    required this.shopName,
    required this.phone,
    required this.description,
    required this.price,
    required this.available,
    this.ownerId = '',
    this.createdAt,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'location': location,
      'shopName': shopName,
      'phone': phone,
      'description': description,
      'price': price,
      'available': available,
      'ownerId': ownerId,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ItemModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final timestamp = map['createdAt'];

    DateTime? parsedCreatedAt;

    if (timestamp is Timestamp) {
      parsedCreatedAt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      parsedCreatedAt = timestamp;
    } else if (timestamp is String) {
      parsedCreatedAt = DateTime.tryParse(timestamp);
    }

    return ItemModel(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      location: map['location'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      available: map['available'] as bool? ?? false,
      ownerId: map['ownerId'] as String? ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
    );
  }

  factory ItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ItemModel.fromMap(
      document.data() ?? <String, dynamic>{},
      id: document.id,
    );
  }
}

