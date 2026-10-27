
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/item_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // লগইন করা ভেন্ডরের প্রোফাইল যাচাই
  Future<Map<String, dynamic>> _getVendorProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('আগে লগইন করুন।');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('আপনার প্রোফাইল পাওয়া যায়নি।');
    }

    final profile = userDoc.data()!;

    final shopName = (profile['shopName'] ?? '').toString().trim();
    final phone = (profile['phone'] ?? '').toString().trim();

    if (shopName.isEmpty || phone.isEmpty) {
      throw Exception(
        'পণ্য যোগ করার আগে প্রোফাইলে দোকানের নাম ও ফোন নম্বর দিন।',
      );
    }

    return {
      ...profile,
      'shopName': shopName,
      'phone': phone,
    };
  }

  // Firestore থেকে পণ্য সংগ্রহ
  Stream<List<ItemModel>> getProducts() {
    return _firestore.collection('products').snapshots().map(
          (snapshot) => snapshot.docs
              .map((document) => ItemModel.fromFirestore(document))
              .toList(),
        );
  }

  // নতুন পণ্য যোগ করা অথবা আগের পণ্যের স্টক বাড়ানো
  Future<void> addProduct(ItemModel item) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('পণ্য যোগ করার আগে লগইন করুন।');
    }

    final profile = await _getVendorProfile();

    final name = item.name.trim();
    final category = item.category.trim();
    final shopName = profile['shopName'] as String;
    final phone = profile['phone'] as String;

    if (name.isEmpty) {
      throw Exception('পণ্যের নাম লিখুন।');
    }

    if (category.isEmpty) {
      throw Exception('পণ্যের ক্যাটাগরি নির্বাচন করুন।');
    }

    if (item.price < 0) {
      throw Exception('পণ্যের দাম সঠিকভাবে লিখুন।');
    }

    if (!item.price.isFinite) {
      throw Exception('পণ্যের দাম সঠিকভাবে লিখুন।');
    }

    if (item.stock < 1) {
      throw Exception('স্টকের পরিমাণ অন্তত ১ হতে হবে।');
    }

    final products = _firestore.collection('products');

    final existing = await products
        .where('ownerId', isEqualTo: user.uid)
        .where('name', isEqualTo: name)
        .where('category', isEqualTo: category)
        .where('shopName', isEqualTo: shopName)
        .limit(2)
        .get();

    if (existing.docs.length > 1) {
      throw Exception(
        'একই পণ্যের একাধিক রেকর্ড পাওয়া গেছে। '
        'Firestore-এ রেকর্ডগুলো যাচাই করুন।',
      );
    }

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      final existingData = existingDoc.data();

      final currentStock = existingData['stock'];

      if (currentStock is! num || currentStock < 0) {
        throw Exception('আগের পণ্যের স্টকের তথ্য সঠিক নয়।');
      }

      final newStock = currentStock.toInt() + item.stock;

      await existingDoc.reference.update({
        'stock': newStock,
        'available': newStock > 0,
        'phone': phone,
      });
    } else {
      final productData = item.toMap();

      productData['name'] = name;
      productData['category'] = category;
      productData['shopName'] = shopName;
      productData['phone'] = phone;
      productData['ownerId'] = user.uid;
      productData['stock'] = item.stock;
      productData['available'] = item.stock > 0;
      productData['createdAt'] = FieldValue.serverTimestamp();

      await products.add(productData);
    }
  }

  // Sample products: বর্তমান ভেন্ডরের তথ্য ব্যবহার
  Future<void> addSampleProducts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Sample Product যোগ করার আগে লগইন করুন।');
    }

    final profile = await _getVendorProfile();

    final shopName = profile['shopName'] as String;
    final phone = profile['phone'] as String;
    final location = (profile['location'] ?? '').toString().trim();

    if (location.isEmpty) {
      throw Exception('প্রোফাইলে দোকানের অবস্থান যোগ করুন।');
    }

    final sampleProducts = <ItemModel>[
      ItemModel(
        name: 'প্যারাসিটামল',
        category: 'ওষুধ',
        location: location,
        shopName: shopName,
        phone: phone,
        description: 'প্যারাসিটামল ট্যাবলেট।',
        price: 20,
        available: true,
        ownerId: user.uid,
        stock: 50,
      ),
      ItemModel(
        name: 'রুই মাছ',
        category: 'খাবার',
        location: location,
        shopName: shopName,
        phone: phone,
        description: 'তাজা রুই মাছ।',
        price: 350,
        available: true,
        ownerId: user.uid,
        stock: 10,
      ),
      ItemModel(
        name: 'Type-C চার্জার',
        category: 'ইলেকট্রনিক্স',
        location: location,
        shopName: shopName,
        phone: phone,
        description: 'Type-C চার্জার।',
        price: 450,
        available: true,
        ownerId: user.uid,
        stock: 15,
      ),
      ItemModel(
        name: 'পুরুষদের টি-শার্ট',
        category: 'কাপড়',
        location: location,
        shopName: shopName,
        phone: phone,
        description: 'বিভিন্ন সাইজ পাওয়া যাচ্ছে।',
        price: 550,
        available: true,
        ownerId: user.uid,
        stock: 20,
      ),
    ];

    final batch = _firestore.batch();
    final collection = _firestore.collection('products');

    for (final item in sampleProducts) {
      final docRef = collection.doc();

      batch.set(docRef, {
        ...item.toMap(),
        'ownerId': user.uid,
        'shopName': shopName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // নিজের পণ্যের তথ্য পরিবর্তন
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('আগে লগইন করুন।');
    }

    if (data.isEmpty) {
      throw Exception('পরিবর্তনের জন্য কোনো তথ্য দেওয়া হয়নি।');
    }

    // মালিকানা ও দোকানের পরিচয় সরাসরি পরিবর্তন করা যাবে না।
    const protectedFields = {
      'ownerId',
      'shopName',
      'phone',
      'createdAt',
    };

    if (data.keys.any(protectedFields.contains)) {
      throw Exception(
        'দোকানের পরিচয় বা মালিকানার তথ্য এখানে পরিবর্তন করা যাবে না।',
      );
    }

    if (data.containsKey('stock')) {
      final stock = data['stock'];

      if (stock is! int || stock < 0) {
        throw Exception(
          'স্টকের পরিমাণ শূন্য বা তার বেশি পূর্ণসংখ্যা হতে হবে।',
        );
      }
    }

    if (data.containsKey('price')) {
      final price = data['price'];

      if (price is! num || !price.isFinite || price < 0) {
        throw Exception('পণ্যের দাম সঠিকভাবে লিখুন।');
      }
    }

    final productRef = _firestore.collection('products').doc(productId);
    final product = await productRef.get();

    if (!product.exists) {
      throw Exception('পণ্যটি পাওয়া যায়নি।');
    }

    if (product.data()?['ownerId'] != user.uid) {
      throw Exception('শুধু নিজের পণ্যের তথ্য পরিবর্তন করতে পারবেন।');
    }

    // স্টক পরিবর্তন হলে available-ও একই সঙ্গে সামঞ্জস্যপূর্ণ রাখতে হবে।
    if (data.containsKey('stock')) {
      final stock = data['stock'] as int;
      data = {
        ...data,
        'available': stock > 0,
      };
    }

    await productRef.update(data);
  }

  // নিজের পণ্য মুছে ফেলা
  Future<void> deleteProduct(String productId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('আগে লগইন করুন।');
    }

    final productRef = _firestore.collection('products').doc(productId);
    final product = await productRef.get();

    if (!product.exists) {
      throw Exception('পণ্যটি পাওয়া যায়নি।');
    }

    if (product.data()?['ownerId'] != user.uid) {
      throw Exception('শুধু নিজের পণ্য মুছতে পারবেন।');
    }

    await productRef.delete();
  }
}

