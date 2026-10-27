import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_product_screen.dart';
import 'my_products_screen.dart';
import 'vendor_profile_screen.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('ড্যাশবোর্ড দেখতে আগে লগইন করুন।'),
        ),
      );
    }

    final productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'ভেন্ডর ড্যাশবোর্ড',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'পণ্যের তথ্য লোড করা যায়নি। '
                  'ইন্টারনেট ও Firestore Rules পরীক্ষা করুন।',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final products = snapshot.data?.docs ?? [];

          final totalProducts = products.length;

          final availableProducts = products.where((doc) {
            return doc.data()['available'] == true;
          }).length;

          final today = DateTime.now();

          final addedToday = products.where((doc) {
            final timestamp = doc.data()['createdAt'];

            if (timestamp is! Timestamp) {
              return false;
            }

            final date = timestamp.toDate();

            return date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
          }).length;

          String shopName = '';

          for (final product in products) {
            final name =
                product.data()['shopName']?.toString().trim() ?? '';

            if (name.isNotEmpty) {
              shopName = name;
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF006A4E),
                        Color(0xFF00A878),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        shopName.isEmpty
                            ? 'আপনার দোকান'
                            : 'স্বাগতম, $shopName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'আপনার পণ্য ও স্টক পরিচালনা করুন',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'দ্রুত কাজ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                _dashboardCard(
                  context,
                  icon: Icons.add_a_photo,
                  title: 'নতুন পণ্য যোগ করুন',
                  subtitle: 'পণ্য যোগ করে স্টক আপডেট করুন',
                  color: const Color(0xFF006A4E),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddProductScreen(),
                      ),
                    );
                  },
                ),

                _dashboardCard(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'আমার পণ্য',
                  subtitle: 'নিজের পণ্য দেখুন ও পরিচালনা করুন',
                  color: const Color(0xFF4D96FF),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyProductsScreen(),
                      ),
                    );
                  },
                ),

                _dashboardCard(
                  context,
                  icon: Icons.storefront,
                  title: 'দোকানের প্রোফাইল',
                  subtitle: 'দোকানের তথ্য দেখুন ও পরিবর্তন করুন',
                  color: const Color(0xFFFFA94D),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VendorProfileScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'আপনার দোকানের তথ্য',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'মোট পণ্য',
                        '$totalProducts',
                        Icons.inventory,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'মজুদে আছে',
                        '$availableProducts',
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'আজ যোগ হয়েছে',
                        '$addedToday',
                        Icons.add_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'ডেটা',
                        'লাইভ',
                        Icons.sync,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: color,
            size: 27,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF006A4E),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
