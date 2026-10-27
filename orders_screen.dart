
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('অর্ডার দেখতে আগে লগইন করুন।'),
        ),
      );
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'আমার অর্ডার',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'অর্ডার লোড করা যায়নি। '
                  'Firestore Rules পরীক্ষা করুন।',
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

          final orders = [...?snapshot.data?.docs];

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'এখনো কোনো অর্ডার নেই',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ক্রেতারা অর্ডার করলে এখানে দেখা যাবে।',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          orders.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aDate = aTime is Timestamp
                ? aTime.toDate()
                : DateTime(2000);

            final bDate = bTime is Timestamp
                ? bTime.toDate()
                : DateTime(2000);

            return bDate.compareTo(aDate);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data();

              final productName =
                  data['productName']?.toString() ?? 'পণ্য';

              final customerName =
                  data['customerName']?.toString() ?? 'ক্রেতা';

              final phone = data['phone']?.toString() ?? '';
              final address = data['address']?.toString() ?? '';
              final quantity = data['quantity']?.toString() ?? '1';

              final price =
                  (data['price'] as num?)?.toDouble() ?? 0;

              final status =
                  data['status']?.toString() ?? 'pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: Color(0xFF006A4E),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _statusBadge(status),
                        ],
                      ),
                      const Divider(height: 24),
                      _infoRow(
                        Icons.person_outline,
                        'ক্রেতা',
                        customerName,
                      ),
                      _infoRow(
                        Icons.phone_outlined,
                        'ফোন',
                        phone,
                      ),
                      _infoRow(
                        Icons.location_on_outlined,
                        'ঠিকানা',
                        address,
                      ),
                      _infoRow(
                        Icons.inventory_2_outlined,
                        'পরিমাণ',
                        quantity,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'মোট দাম: ৳${(price * (int.tryParse(quantity) ?? 1)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006A4E),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(
                              context,
                              order.id,
                              'accepted',
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('অর্ডার গ্রহণ করুন'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF006A4E),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),

                      if (status == 'accepted')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(
                              context,
                              order.id,
                              'completed',
                            ),
                            icon: const Icon(Icons.done_all),
                            label: const Text('অর্ডার সম্পন্ন করুন'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),

                      if (status == 'completed')
                        const Text(
                          'অর্ডার সম্পন্ন হয়েছে',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
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

  static Widget _statusBadge(String status) {
    late final String label;
    late final Color color;

    switch (status) {
      case 'accepted':
        label = 'গৃহীত';
        color = Colors.blue;
        break;
      case 'completed':
        label = 'সম্পন্ন';
        color = Colors.green;
        break;
      case 'cancelled':
        label = 'বাতিল';
        color = Colors.red;
        break;
      default:
        label = 'অপেক্ষমাণ';
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  static Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'দেওয়া হয়নি' : value),
          ),
        ],
      ),
    );
  }

  static Future<void> _updateStatus(
    BuildContext context,
    String orderId,
    String newStatus,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('আগে লগইন করুন।');
      }

      if (newStatus != 'accepted' &&
          newStatus != 'completed') {
        throw Exception('অর্ডারের স্ট্যাটাস সঠিক নয়।');
      }

      final firestore = FirebaseFirestore.instance;

      final orderRef =
          firestore.collection('orders').doc(orderId);

      // Notification-এর ID আগে তৈরি করা হচ্ছে।
      final notificationRef =
          firestore.collection('notifications').doc();

      await firestore.runTransaction((transaction) async {
        // Transaction-এর সব read আগে করতে হবে।
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('অর্ডারটি পাওয়া যায়নি।');
        }

        final orderData = orderSnapshot.data();

        if (orderData == null) {
          throw Exception('অর্ডারের তথ্য পাওয়া যায়নি।');
        }

        if (orderData['vendorId'] != user.uid) {
          throw Exception('এই অর্ডার পরিবর্তনের অনুমতি নেই।');
        }

        final oldStatus =
            orderData['status']?.toString() ?? '';

        // শুধু অনুমোদিত status transition।
        if (newStatus == 'accepted' &&
            oldStatus != 'pending') {
          throw Exception(
            'শুধু অপেক্ষমাণ অর্ডার গ্রহণ করা যাবে।',
          );
        }

        if (newStatus == 'completed' &&
            oldStatus != 'accepted') {
          throw Exception(
            'আগে অর্ডার গ্রহণ করতে হবে।',
          );
        }

        final customerId =
            orderData['customerId']?.toString() ?? '';

        if (customerId.isEmpty ||
            customerId == user.uid) {
          throw Exception(
            'ক্রেতার সঠিক তথ্য পাওয়া যায়নি।',
          );
        }

        final productName =
            orderData['productName']?.toString() ?? 'পণ্য';

        // Order-এর status পরিবর্তন।
        transaction.update(orderRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Customer-এর জন্য notification তৈরি।
        final bool accepted = newStatus == 'accepted';

        transaction.set(notificationRef, {
          'userId': customerId,
          'title': accepted
              ? 'আপনার অর্ডার গ্রহণ করা হয়েছে!'
              : 'আপনার অর্ডার সম্পন্ন হয়েছে!',
          'body': accepted
              ? 'আপনার "$productName" অর্ডারটি বিক্রেতা গ্রহণ করেছেন।'
              : 'আপনার "$productName" অর্ডারটি সম্পন্ন হয়েছে।',
          'type': accepted
              ? 'order_accepted'
              : 'order_completed',
          'orderId': orderRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'accepted'
                ? 'অর্ডার গ্রহণ করা হয়েছে। ক্রেতাকে নোটিফিকেশন পাঠানো হয়েছে।'
                : 'অর্ডার সম্পন্ন হয়েছে। ক্রেতাকে নোটিফিকেশন পাঠানো হয়েছে।',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Update order error: ${e.code} - ${e.message}',
      );

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'আপডেট ব্যর্থ: ${e.code}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Update order error: $e');

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }
}

