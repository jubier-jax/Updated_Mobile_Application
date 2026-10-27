import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/product_service.dart';
import 'login_screen.dart';

class AddSampleProductsScreen extends StatefulWidget {
  const AddSampleProductsScreen({super.key});

  @override
  State<AddSampleProductsScreen> createState() =>
      _AddSampleProductsScreenState();
}

class _AddSampleProductsScreenState
    extends State<AddSampleProductsScreen> {
  bool isLoading = false;
  bool isCheckingLogin = true;
  String message = '';

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      });
    } else {
      setState(() {
        isCheckingLogin = false;
      });
    }
  }

  Future<void> addSamples() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        message = 'প্রথমে লগইন করুন।';
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      await ProductService().addSampleProducts();

      if (!mounted) return;

      setState(() {
        message = 'চারটি Sample Product সফলভাবে Firestore-এ যোগ হয়েছে!';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        message = 'সমস্যা হয়েছে: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingLogin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Products যোগ করুন'),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 70,
                color: Color(0xFF006A4E),
              ),
              const SizedBox(height: 20),
              const Text(
                'Firestore-এ চারটি Sample Product যোগ করুন',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : addSamples,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A4E),
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Sample Products যোগ করুন'),
                ),
              ),
              const SizedBox(height: 20),
              if (message.isNotEmpty)
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
