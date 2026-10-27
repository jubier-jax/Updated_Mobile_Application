
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerOrderHistoryScreen extends StatelessWidget {
  const CustomerOrderHistoryScreen({super.key});

  static const Color primaryColor = Color(0xFF006A4E);

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'গৃহীত';
      case 'completed':
        return 'সম্পন্ন';
      case 'cancelled':
        return 'বাতিল';
      default:
        return 'অপেক্ষমাণ';
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String formatDate(dynamic value) {
    if (value is! Timestamp) {
      return 'তারিখ পাওয়া যায়নি';
    }

    final date = value.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day-$month-$year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('আমার অর্ডার'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('অর্ডার দেখতে আগে লগইন করুন।'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'আমার অর্ডার',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'অর্ডার লোড করা যায়নি।',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          final orders = snapshot.data?.docs.toList() ?? [];

          debugPrint('Customer UID: ${user.uid}');
          debugPrint('Orders found: ${orders.length}');

          orders.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aDate = aTime is Timestamp
                ? aTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            final bDate = bTime is Timestamp
                ? bTime.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          });

          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 76,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'এখনও কোনো অর্ডার দেখানো যাচ্ছে না',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'বর্তমান অ্যাকাউন্টের UID:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      user.uid,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final document = orders[index];
              final data = document.data();

              final productName =
                  (data['productName'] ?? 'পণ্যের নাম নেই').toString();

              final shopName =
                  (data['shopName'] ?? 'দোকানের নাম নেই').toString();

              final status =
                  (data['status'] ?? 'pending').toString();

              final quantity = data['quantity'] is num
                  ? (data['quantity'] as num).toInt()
                  : 0;

              final totalPrice = data['totalPrice'] is num
                  ? (data['totalPrice'] as num).toDouble()
                  : 0.0;

              final color = statusColor(status);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2F1),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shopName,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel(status),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _infoRow('পরিমাণ', '$quantity টি'),
                      const SizedBox(height: 10),
                      _infoRow(
                        'মোট মূল্য',
                        '৳${totalPrice.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        'অর্ডারের তারিখ',
                        formatDate(data['createdAt']),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        'অর্ডার নম্বর',
                        (data['orderId'] ?? document.id).toString(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

