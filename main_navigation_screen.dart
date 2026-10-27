
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'add_product_screen.dart';
import 'vendor_dashboard_screen.dart';
import 'vendor_profile_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import 'customer_order_history_screen.dart';
import 'notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int selectedIndex = 0;

  late Future<String> roleFuture;

  @override
  void initState() {
    super.initState();
    roleFuture = loadUserRole();
  }

  Future<String> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 'customer';
    }

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = document.data()?['role'];

    return role == 'vendor' ? 'vendor' : 'customer';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF006A4E),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('তথ্য লোড করা যায়নি।'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        roleFuture = loadUserRole();
                      });
                    },
                    child: const Text('আবার চেষ্টা করুন'),
                  ),
                ],
              ),
            ),
          );
        }

        final role = snapshot.data ?? 'customer';
        final isVendor = role == 'vendor';

        final List<Widget> screens = isVendor
            ? [
                const HomeScreen(),
                const VendorDashboardScreen(),
                const AddProductScreen(),
                const OrdersScreen(),
                const NotificationsScreen(),
                const VendorProfileScreen(),
                const ProfileScreen(),
              ]
            : [
                const HomeScreen(),
                const CustomerOrderHistoryScreen(),
                const NotificationsScreen(),
                const ProfileScreen(),
              ];

        final List<NavigationDestination> destinations = isVendor
            ? [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'হোম',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'ড্যাশবোর্ড',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.add_box_outlined),
                  selectedIcon: Icon(Icons.add_box),
                  label: 'পণ্য যোগ',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'অর্ডার',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'নোটিফাই',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.store_outlined),
                  selectedIcon: Icon(Icons.store),
                  label: 'দোকান',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'প্রোফাইল',
                ),
              ]
            : [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'হোম',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'অর্ডার',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'নোটিফাই',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'প্রোফাইল',
                ),
              ];

        // Role বা screen list পরিবর্তিত হলে index সীমার মধ্যে রাখি।
        final safeIndex = selectedIndex < screens.length
            ? selectedIndex
            : 0;

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFE0F2F1),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

