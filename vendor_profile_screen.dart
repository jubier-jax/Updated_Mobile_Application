
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/item_model.dart';
import '../services/product_service.dart';
import 'item_details_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() =>
      _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool savingLocation = false;

  Future<Map<String, dynamic>?> getVendorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await firestore
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  Future<void> _saveShopLocation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('প্রথমে লগইন করুন।');
      return;
    }

    if (savingLocation) return;

    setState(() {
      savingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('ফোনের GPS/Location চালু করুন।');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'অ্যাপের Location permission চালু করে আবার চেষ্টা করুন।',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latitude = position.latitude;
      final longitude = position.longitude;
      final timestamp = FieldValue.serverTimestamp();

      debugPrint('GPS: $latitude, $longitude');

      // Vendor-এর ব্যক্তিগত Profile document
      final vendorRef = firestore
          .collection('users')
          .doc(user.uid);

      // Customer-দের জন্য প্রকাশযোগ্য Shop Location
      final publicShopRef = firestore
          .collection('publicShops')
          .doc(user.uid);

      // দুই document-এ location একসঙ্গে সেভ হবে।
      final batch = firestore.batch();

      batch.set(
        vendorRef,
        {
          'shopLatitude': latitude,
          'shopLongitude': longitude,
          'shopLocationUpdatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      batch.set(
        publicShopRef,
        {
          'shopLatitude': latitude,
          'shopLongitude': longitude,
          'shopLocationUpdatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Save সফল হয়েছে কি না যাচাই
      final savedDocument = await publicShopRef.get();
      final savedData = savedDocument.data();

      if (savedDocument.exists &&
          savedData?['shopLatitude'] is num &&
          savedData?['shopLongitude'] is num) {
        debugPrint('Location saved to users and publicShops.');

        if (!mounted) return;

        _showMessage(
          'দোকানের লোকেশন সফলভাবে সেভ হয়েছে।',
        );

        setState(() {});
      } else {
        throw Exception(
          'publicShops document-এ location যাচাই করা যায়নি।',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Shop location error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Location save error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          savingLocation = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _deleteProduct(
    BuildContext context,
    ItemModel item,
    ProductService service,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('পণ্য মুছে ফেলবেন?'),
        content: Text('“${item.name}” পণ্যটি মুছে ফেলা হবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await service.deleteProduct(item.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('পণ্য মুছে ফেলা হয়েছে।'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('পণ্য মুছতে সমস্যা হয়েছে: $e'),
        ),
      );
    }
  }

  void _editProduct(
    BuildContext context,
    ItemModel item,
    ProductService service,
  ) {
    final nameController = TextEditingController(text: item.name);
    final priceController =
        TextEditingController(text: item.price.toString());
    final stockController =
        TextEditingController(text: item.stock.toString());
    final descriptionController =
        TextEditingController(text: item.description);

    String category = item.category;
    String location = item.location;
    bool saving = false;

    const categories = [
      'খাবার',
      'ওষুধ',
      'ইলেকট্রনিক্স',
      'মুদি',
      'কাপড়',
      'সেবা',
    ];

    const locations = [
      'চাঁদপুর সদর',
      'হাজীগঞ্জ',
      'ফরিদগঞ্জ',
      'মতলব উত্তর',
      'মতলব দক্ষিণ',
      'কচুয়া',
      'শাহরাস্তি',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('পণ্য সম্পাদনা'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'পণ্যের নাম',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(category)
                      ? category
                      : categories.first,
                  decoration: const InputDecoration(
                    labelText: 'ক্যাটাগরি',
                  ),
                  items: categories
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => category = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'দাম (৳)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'স্টক',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: locations.contains(location)
                      ? location
                      : locations.first,
                  decoration: const InputDecoration(
                    labelText: 'এলাকা',
                  ),
                  items: locations
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => location = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'বিবরণ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );
                      final stock = int.tryParse(
                        stockController.text.trim(),
                      );

                      if (name.isEmpty ||
                          price == null ||
                          price < 0 ||
                          stock == null ||
                          stock < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'নাম, দাম ও স্টক সঠিকভাবে দিন।',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        await service.updateProduct(
                          item.id,
                          {
                            'name': name,
                            'category': category,
                            'location': location,
                            'price': price,
                            'stock': stock,
                            'available': stock > 0,
                            'description':
                                descriptionController.text.trim(),
                          },
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'পণ্যের তথ্য আপডেট হয়েছে।',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('আপডেট করা যায়নি: $e'),
                            ),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'সেভ হচ্ছে...' : 'সেভ করুন'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();
      descriptionController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = ProductService();

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('প্রথমে লগইন করুন।'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: getVendorData(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (profileSnapshot.hasError) {
            return const Center(
              child: Text('প্রোফাইল লোড করা যায়নি।'),
            );
          }

          final data = profileSnapshot.data;

          if (data == null) {
            return const Center(
              child: Text('প্রোফাইলের তথ্য পাওয়া যায়নি।'),
            );
          }

          final name = data['name']?.toString() ?? 'নাম দেওয়া হয়নি';
          final email = data['email']?.toString() ?? user.email ?? '';
          final phone =
              data['phone']?.toString() ?? 'ফোন নম্বর দেওয়া হয়নি';
          final shopName = data['shopName']?.toString() ??
              'দোকানের নাম দেওয়া হয়নি';
          final location =
              data['location']?.toString() ?? 'লোকেশন দেওয়া হয়নি';

          final latitude = data['shopLatitude'];
          final longitude = data['shopLongitude'];
          final hasShopGps = latitude is num && longitude is num;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CircleAvatar(
                radius: 45,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(
                  Icons.store,
                  size: 45,
                  color: Color(0xFF006A4E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                shopName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(name, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('দোকানদার'),
                      subtitle: Text(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('ইমেইল'),
                      subtitle: Text(email),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('ফোন'),
                      subtitle: Text(phone),
                    ),
                    ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('দোকান'),
                      subtitle: Text(shopName),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: const Text('এলাকা'),
                      subtitle: Text(location),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            color: Color(0xFF006A4E),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'দোকানের GPS লোকেশন',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasShopGps) ...[
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text('লোকেশন সেভ করা আছে'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'Latitude: ${latitude.toString()}\n'
                          'Longitude: ${longitude.toString()}',
                        ),
                      ] else
                        const Text(
                          'এখনো দোকানের GPS লোকেশন সেভ করা হয়নি।',
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: savingLocation
                              ? null
                              : _saveShopLocation,
                          icon: savingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(
                            savingLocation
                                ? 'লোকেশন সেভ হচ্ছে...'
                                : hasShopGps
                                    ? 'দোকানের লোকেশন আপডেট করুন'
                                    : 'দোকানের বর্তমান লোকেশন সেভ করুন',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF006A4E),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'দোকানের ঠিক জায়গায় দাঁড়িয়ে এই বাটন চাপুন। '
                        'এটি ফোনের বর্তমান GPS অবস্থান সেভ করবে।',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'আমার পণ্য',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<ItemModel>>(
                stream: service.getProducts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('পণ্য লোড করা যায়নি।');
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final products = snapshot.data!
                      .where((item) => item.ownerId == user.uid)
                      .toList();

                  if (products.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('এখনো কোনো পণ্য যোগ করা হয়নি।'),
                    );
                  }

                  return Column(
                    children: products.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(
                            Icons.shopping_bag,
                            color: Color(0xFF006A4E),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.category} • '
                            '৳${item.price.toStringAsFixed(0)} • '
                            'স্টক: ${item.stock}',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailsScreen(item: item),
                              ),
                            );
                          },
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _editProduct(
                                  context,
                                  item,
                                  service,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteProduct(
                                  context,
                                  item,
                                  service,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
