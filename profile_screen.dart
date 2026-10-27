import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
const ProfileScreen({super.key});

Future<Map<String, dynamic>?> getUserData() async {
final user = FirebaseAuth.instance.currentUser;


if (user == null) return null;

final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

if (doc.exists) {
  return doc.data();
}

return {
  'name': user.displayName ?? 'নাম দেওয়া হয়নি',
  'email': user.email ?? 'ইমেইল দেওয়া হয়নি',
  'phone': 'ফোন নম্বর দেওয়া হয়নি',
  'location': 'লোকেশন দেওয়া হয়নি',
  'role': 'customer',
};


}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF7F9FC),
appBar: AppBar(
title: const Text(
'আমার প্রোফাইল',
style: TextStyle(fontWeight: FontWeight.bold),
),
backgroundColor: const Color(0xFF006A4E),
foregroundColor: Colors.white,
),
body: FutureBuilder<Map<String, dynamic>?>(
future: getUserData(),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(
color: Color(0xFF006A4E),
),
);
}


      final data = snapshot.data;

      if (data == null) {
        return const Center(
          child: Text('প্রোফাইল দেখতে প্রথমে লগইন করুন।'),
        );
      }

      final name = data['name']?.toString() ?? 'নাম দেওয়া হয়নি';
      final email = data['email']?.toString() ?? 'ইমেইল দেওয়া হয়নি';
      final phone = data['phone']?.toString() ?? 'ফোন নম্বর দেওয়া হয়নি';
      final location = data['location']?.toString() ?? 'লোকেশন দেওয়া হয়নি';
      final role = data['role']?.toString() ?? 'customer';

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(
                Icons.person,
                size: 55,
                color: Color(0xFF006A4E),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              role == 'vendor' ? 'Vendor' : 'Customer',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 25),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  _profileTile(
                    icon: Icons.person_outline,
                    title: 'নাম',
                    value: name,
                  ),
                  const Divider(height: 1),
                  _profileTile(
                    icon: Icons.email_outlined,
                    title: 'ইমেইল',
                    value: email,
                  ),
                  const Divider(height: 1),
                  _profileTile(
                    icon: Icons.phone_outlined,
                    title: 'ফোন নম্বর',
                    value: phone,
                  ),
                  const Divider(height: 1),
                  _profileTile(
                    icon: Icons.location_on_outlined,
                    title: 'লোকেশন',
                    value: location,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Colors.grey,
                    ),
                    title: const Text('Settings'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: Colors.grey,
                    ),
                    title: const Text('Help & Support'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Help & Support coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text(
                        'আপনি কি Logout করতে চান?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, false);
                          },
                          child: const Text('না'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, true);
                          },
                          child: const Text('হ্যাঁ'),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true || !context.mounted) return;

                  await FirebaseAuth.instance.signOut();

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  ),
);


}

Widget _profileTile({
required IconData icon,
required String title,
required String value,
}) {
return ListTile(
leading: Icon(
icon,
color: const Color(0xFF006A4E),
),
title: Text(title),
subtitle: Text(value),
);
}
}
