
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color primaryColor = Color(0xFF006A4E);

  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('নোটিফিকেশন'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('নোটিফিকেশন দেখতে আগে লগইন করুন।'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'নোটিফিকেশন',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'নোটিফিকেশন লোড করা যায়নি:\n${snapshot.error}',
                  textAlign: TextAlign.center,
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

          final notifications = snapshot.data?.docs.toList() ?? [];

          notifications.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aDate =
                aTime is Timestamp ? aTime.toDate() : DateTime(2000);
            final bDate =
                bTime is Timestamp ? bTime.toDate() : DateTime(2000);

            return bDate.compareTo(aDate);
          });

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 76,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'এখনো কোনো নোটিফিকেশন নেই',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'নতুন আপডেট এখানে দেখা যাবে।',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final document = notifications[index];
              final data = document.data();

              final title =
                  (data['title'] ?? 'নতুন নোটিফিকেশন').toString();
              final body = (data['body'] ?? '').toString();
              final isRead = data['isRead'] == true;
              final createdAt = data['createdAt'];

              String dateText = 'সময় পাওয়া যায়নি';

              if (createdAt is Timestamp) {
                final date = createdAt.toDate();
                dateText =
                    '${date.day.toString().padLeft(2, '0')}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                color: isRead
                    ? Colors.white
                    : const Color(0xFFE8F5E9),
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.12),
                    child: Icon(
                      isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: primaryColor,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body),
                        const SizedBox(height: 8),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'নতুন',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  onTap: isRead
                      ? null
                      : () async {
                          try {
                            await markAsRead(document.id);
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'নোটিফিকেশন আপডেট হয়নি: $e',
                                ),
                              ),
                            );
                          }
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
