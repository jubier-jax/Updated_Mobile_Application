
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_model.dart';
import '../services/product_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final productNameController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController(text: '1');
  final descriptionController = TextEditingController();

  final ProductService productService = ProductService();

  String selectedCategory = 'খাবার';
  String selectedLocation = 'চাঁদপুর সদর';

  String shopName = '';
  String phone = '';
  String vendorLocation = '';

  bool isSaving = false;
  bool isLoadingProfile = true;
  String? profileError;

  final List<String> categories = [
    'খাবার',
    'ওষুধ',
    'ইলেকট্রনিক্স',
    'মুদি',
    'কাপড়',
    'সেবা',
  ];

  final List<String> locations = [
    'চাঁদপুর সদর',
    'হাজীগঞ্জ',
    'ফরিদগঞ্জ',
    'মতলব উত্তর',
    'মতলব দক্ষিণ',
    'কচুয়া',
    'শাহরাস্তি',
  ];

  @override
  void initState() {
    super.initState();
    loadVendorProfile();
  }

  Future<void> loadVendorProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('প্রথমে লগইন করুন।');
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('আপনার Vendor Profile পাওয়া যায়নি।');
      }

      final data = doc.data()!;

      final loadedShopName = data['shopName']?.toString().trim() ?? '';
      final loadedPhone = data['phone']?.toString().trim() ?? '';
      final loadedLocation = data['location']?.toString().trim() ?? '';

      if (loadedShopName.isEmpty ||
          loadedShopName == 'দোকানের নাম দেওয়া হয়নি') {
        throw Exception('প্রথমে Profile-এ দোকানের নাম যোগ করুন।');
      }

      if (loadedPhone.isEmpty ||
          loadedPhone == 'ফোন নম্বর দেওয়া হয়নি') {
        throw Exception('প্রথমে Profile-এ ফোন নম্বর যোগ করুন।');
      }

      if (!mounted) return;

      setState(() {
        shopName = loadedShopName;
        phone = loadedPhone;
        vendorLocation = loadedLocation;

        if (locations.contains(loadedLocation)) {
          selectedLocation = loadedLocation;
        }

        isLoadingProfile = false;
        profileError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingProfile = false;
        profileError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> addProduct() async {
    if (isSaving || isLoadingProfile) return;

    if (FirebaseAuth.instance.currentUser == null) {
      showMessage('পণ্য যোগ করার আগে লগইন করুন।');
      return;
    }

    if (profileError != null || shopName.isEmpty || phone.isEmpty) {
      showMessage('আপনার দোকানের তথ্য পাওয়া যায়নি। Profile যাচাই করুন।');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(priceController.text.trim());
    final stock = int.tryParse(stockController.text.trim());

    if (price == null || price < 0 || stock == null || stock < 1) {
      showMessage('দাম ও স্টকের পরিমাণ সঠিকভাবে লিখুন।');
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // দোকানের নাম ও ফোন নম্বর Profile থেকে নেওয়া হচ্ছে।
      final product = ItemModel(
        name: productNameController.text.trim(),
        category: selectedCategory,
        location: selectedLocation,
        shopName: shopName,
        phone: phone,
        description: descriptionController.text.trim(),
        price: price,
        available: true,
        ownerId: user.uid,
        stock: stock,
      );

      await productService.addProduct(product);

      if (!mounted) return;

      showMessage(
        'পণ্য ও স্টকের তথ্য সফলভাবে সেভ হয়েছে!',
        color: const Color(0xFF006A4E),
      );

      productNameController.clear();
      priceController.clear();
      stockController.text = '1';
      descriptionController.clear();

      setState(() {
        selectedCategory = 'খাবার';
        selectedLocation = locations.contains(vendorLocation)
            ? vendorLocation
            : 'চাঁদপুর সদর';
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'পণ্য যোগ করা যায়নি: $e',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void showMessage(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    productNameController.dispose();
    priceController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('পণ্য যোগ করুন'),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF006A4E),
              ),
            )
          : profileError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 55,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          profileError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              isLoadingProfile = true;
                              profileError = null;
                            });
                            loadVendorProfile();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('আবার চেষ্টা করুন'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'নতুন পণ্য যোগ করুন',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'দোকানের পরিচয় আপনার Vendor Profile থেকে নেওয়া হয়েছে।',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // দোকানের পরিচয় Profile থেকে আসছে।
                        Card(
                          color: const Color(0xFFE8F5E9),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.store,
                                  color: Color(0xFF006A4E),
                                ),
                                title: const Text('দোকানের নাম'),
                                subtitle: Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.phone,
                                  color: Color(0xFF006A4E),
                                ),
                                title: const Text('ফোন নম্বর'),
                                subtitle: Text(phone),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        TextFormField(
                          controller: productNameController,
                          enabled: !isSaving,
                          decoration: fieldDecoration(
                            label: 'পণ্যের নাম',
                            hint: 'যেমন: তাজা রুই মাছ',
                            icon: Icons.shopping_bag_outlined,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'পণ্যের নাম লিখুন'
                                  : null,
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: fieldDecoration(
                            label: 'ক্যাটাগরি',
                            icon: Icons.category_outlined,
                          ),
                          items: categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(
                                      () => selectedCategory = value,
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: priceController,
                          enabled: !isSaving,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: fieldDecoration(
                            label: 'দাম',
                            hint: 'যেমন: 350',
                            icon: Icons.payments_outlined,
                          ).copyWith(prefixText: '৳ '),
                          validator: (value) {
                            final price = double.tryParse(
                              value?.trim() ?? '',
                            );

                            if (price == null || price < 0) {
                              return 'সঠিক দাম লিখুন';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: stockController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: fieldDecoration(
                            label: 'স্টকের পরিমাণ',
                            hint: 'যেমন: 20',
                            icon: Icons.inventory_2_outlined,
                          ).copyWith(
                            helperText:
                                'আগের একই পণ্য যোগ করলে স্টক বাড়বে।',
                          ),
                          validator: (value) {
                            final stock = int.tryParse(
                              value?.trim() ?? '',
                            );

                            if (stock == null || stock < 1) {
                              return 'কমপক্ষে ১টি পণ্য থাকতে হবে';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: selectedLocation,
                          decoration: fieldDecoration(
                            label: 'পণ্যের এলাকা',
                            icon: Icons.location_on_outlined,
                          ),
                          items: locations
                              .map(
                                (location) => DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(
                                      () => selectedLocation = value,
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: descriptionController,
                          enabled: !isSaving,
                          maxLines: 4,
                          decoration: fieldDecoration(
                            label: 'পণ্যের বিবরণ',
                            hint: 'পণ্য সম্পর্কে বিস্তারিত লিখুন',
                            icon: Icons.description_outlined,
                          ).copyWith(alignLabelWithHint: true),
                        ),
                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : addProduct,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              isSaving ? 'সেভ হচ্ছে...' : 'পণ্য সেভ করুন',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006A4E),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

