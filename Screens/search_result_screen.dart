
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/item_model.dart';
import 'item_details_screen.dart';

class SearchResultScreen extends StatelessWidget {
  final List<ItemModel> results;

  const SearchResultScreen({
    super.key,
    required this.results,
  });

  // ফোন কল করার ফাংশন
  Future<void> _makePhoneCall(String phone) async {
    if (phone.trim().isEmpty) return;

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  // পণ্য কতক্ষণ আগে যোগ করা হয়েছে তা বের করা
  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) {
      return 'যোগ করার সময় পাওয়া যায়নি';
    }

    try {
      DateTime createdDate;

      if (createdAt is DateTime) {
        createdDate = createdAt;
      } else {
        // Firestore Timestamp হলে DateTime-এ রূপান্তর হবে।
        createdDate = createdAt.toDate() as DateTime;
      }

      final now = DateTime.now();

      if (createdDate.isAfter(now)) {
        return 'এইমাত্র যোগ করা হয়েছে';
      }

      final difference = now.difference(createdDate);

      if (difference.inSeconds < 60) {
        return 'এইমাত্র যোগ করা হয়েছে';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} মিনিট আগে যোগ করা হয়েছে';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours} ঘণ্টা আগে যোগ করা হয়েছে';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays} দিন আগে যোগ করা হয়েছে';
      }

      if (difference.inDays < 30) {
        return '${difference.inDays ~/ 7} সপ্তাহ আগে যোগ করা হয়েছে';
      }

      if (difference.inDays < 365) {
        return '${difference.inDays ~/ 30} মাস আগে যোগ করা হয়েছে';
      }

      return '${difference.inDays ~/ 365} বছর আগে যোগ করা হয়েছে';
    } catch (_) {
      return 'যোগ করার সময় পাওয়া যায়নি';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'খোঁজার ফলাফল',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: results.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'কোনো পণ্য পাওয়া যায়নি',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'অন্য কিছু দিয়ে আবার চেষ্টা করুন',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // পণ্যের আইকন
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Color(0xFF006A4E),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // পণ্যের তথ্য
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.category,
                                    style: const TextStyle(
                                      color: Color(0xFF006A4E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 7),

                                  // দোকানের নাম
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.store,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          item.shopName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // ফোন নম্বর
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          item.phone,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // অবস্থান
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          item.location,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // পণ্যের মজুদের অবস্থা
                            Column(
                              children: [
                                Icon(
                                  item.available
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: item.available
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.available ? 'মজুদ আছে' : 'নেই',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: item.available
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // পণ্য যোগ করার সময়
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Color(0xFF006A4E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _timeAgo(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF006A4E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // পণ্যের বিবরণ
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // পণ্যের দাম
                        Text(
                          '৳${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // বিস্তারিত ও কল বাটন
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ItemDetailsScreen(item: item),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                ),
                                label: const Text('বিস্তারিত'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF006A4E),
                                  side: const BorderSide(
                                    color: Color(0xFF006A4E),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: item.available
                                    ? () => _makePhoneCall(item.phone)
                                    : null,
                                icon: const Icon(
                                  Icons.call,
                                  size: 18,
                                ),
                                label: const Text('কল করুন'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF006A4E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

