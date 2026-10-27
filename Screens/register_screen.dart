import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_navigation_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool obscurePassword = true;
  bool isLoading = false;

  String selectedRole = 'customer';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    shopNameController.dispose();
    locationController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> register() async {
    final String name = nameController.text.trim();
    final String phone = phoneController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String shopName = shopNameController.text.trim();
    final String location = locationController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        location.isEmpty) {
      showMessage('দয়া করে প্রয়োজনীয় সব তথ্য পূরণ করুন');
      return;
    }

    if (selectedRole == 'vendor' && shopName.isEmpty) {
      showMessage('আপনার দোকানের নাম লিখুন');
      return;
    }

    if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
      showMessage('সঠিক ১১ সংখ্যার মোবাইল নম্বর দিন');
      return;
    }

    if (password.length < 6) {
      showMessage('পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে');
      return;
    }

    setState(() {
      isLoading = true;
    });

    User? createdUser;
    bool profileSaved = false;

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw Exception('Account creation failed');
      }

      createdUser = user;

      await user.updateDisplayName(name);

      final Map<String, dynamic> userData = {
        'uid': user.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'role': selectedRole,
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (selectedRole == 'vendor') {
        userData['shopName'] = shopName;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      profileSaved = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে'),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'এই ইমেইল দিয়ে আগে থেকেই অ্যাকাউন্ট আছে';
          break;
        case 'invalid-email':
          message = 'সঠিক ইমেইল ঠিকানা দিন';
          break;
        case 'weak-password':
          message = 'আরও শক্তিশালী পাসওয়ার্ড দিন';
          break;
        case 'operation-not-allowed':
          message = 'Firebase Console-এ Email/Password চালু করুন';
          break;
        case 'network-request-failed':
          message = 'ইন্টারনেট সংযোগ পরীক্ষা করুন';
          break;
        default:
          message = 'অ্যাকাউন্ট তৈরি করা যায়নি: ${e.message ?? e.code}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (createdUser != null && !profileSaved) {
        try {
          await createdUser.delete();
        } catch (_) {
          // প্রয়োজনে Firebase Console থেকে অসম্পূর্ণ অ্যাকাউন্ট পরীক্ষা করুন।
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'তথ্য সংরক্ষণ করা যায়নি। ইন্টারনেট ও Firestore Rules পরীক্ষা করুন।',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF006A4E),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget buildRoleOption({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = selectedRole == role;

    return Expanded(
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE0F2F1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF006A4E)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
                color: const Color(0xFF006A4E),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF006A4E),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'রেজিস্টার',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'নতুন অ্যাকাউন্ট তৈরি করুন',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'আপনি ক্রেতা অথবা বিক্রেতা হিসেবে নিবন্ধন করতে পারবেন।',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),

              const Text(
                'আপনি কোন ধরনের অ্যাকাউন্ট চান?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  buildRoleOption(
                    role: 'customer',
                    title: 'ক্রেতা',
                    subtitle: 'পণ্য খুঁজুন ও অর্ডার করুন',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(width: 12),
                  buildRoleOption(
                    role: 'vendor',
                    title: 'বিক্রেতা',
                    subtitle: 'দোকান খুলুন ও পণ্য বিক্রি করুন',
                    icon: Icons.store_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                'আপনার নাম',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: inputDecoration(
                  hint: 'আপনার নাম লিখুন',
                  icon: Icons.person_outline,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'মোবাইল নম্বর',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: inputDecoration(
                  hint: '01XXXXXXXXX',
                  icon: Icons.phone,
                ).copyWith(counterText: ''),
              ),

              const SizedBox(height: 18),

              const Text(
                'আপনার এলাকা',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                textCapitalization: TextCapitalization.words,
                decoration: inputDecoration(
                  hint: 'যেমন: চাঁদপুর সদর',
                  icon: Icons.location_on_outlined,
                ),
              ),

              if (selectedRole == 'vendor') ...[
                const SizedBox(height: 18),
                const Text(
                  'দোকানের নাম',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shopNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: inputDecoration(
                    hint: 'আপনার দোকানের নাম লিখুন',
                    icon: Icons.store_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF006A4E),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'বিক্রেতা হিসেবেও আপনি অন্য দোকানের পণ্য অর্ডার করতে পারবেন।',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              const Text(
                'ইমেইল ঠিকানা',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: inputDecoration(
                  hint: 'example@email.com',
                  icon: Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'পাসওয়ার্ড',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: inputDecoration(
                  hint: 'কমপক্ষে ৬ অক্ষর',
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A4E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'অ্যাকাউন্ট তৈরি করুন',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'আগেই অ্যাকাউন্ট আছে?',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'লগইন করুন',
                      style: TextStyle(
                        color: Color(0xFF006A4E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
