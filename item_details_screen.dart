
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/item_model.dart';
import 'place_order_screen.dart';

class ItemDetailsScreen extends StatefulWidget {
  final ItemModel item;

  const ItemDetailsScreen({
    super.key,
    required this.item,
  });

  @override
  State<ItemDetailsScreen> createState() =>
      _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  Position? customerPosition;
  double? distanceInKm;
  double? shopLatitude;
  double? shopLongitude;

  bool loadingLocation = false;

  ItemModel get item => widget.item;

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> makePhoneCall(BuildContext context) async {
    final phone = item.phone.trim();

    if (phone.isEmpty) {
      showMessage('এই পণ্যের ফোন নম্বর দেওয়া নেই।');
      return;
    }

    final phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      final launched = await launchUrl(phoneUri);

      if (!launched) {
        showMessage('ফোন কল চালু করা যায়নি।');
      }
    } catch (e) {
      debugPrint('Phone call error: $e');
      showMessage('ফোন কল করতে সমস্যা হয়েছে।');
    }
  }

  void openOrderScreen(BuildContext context) {
    if (!item.available) {
      showMessage('দুঃখিত, পণ্যটি বর্তমানে পাওয়া যাচ্ছে না।');
      return;
    }

    if (item.ownerId.trim().isEmpty) {
      showMessage('এই পণ্যের দোকানদারের তথ্য পাওয়া যায়নি।');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceOrderScreen(item: item),
      ),
    );
  }

  Future<void> findShopAndDistance() async {
    if (loadingLocation) return;

    if (item.ownerId.trim().isEmpty) {
      showMessage('দোকানদারের তথ্য পাওয়া যায়নি।');
      return;
    }

    setState(() {
      loadingLocation = true;
    });

    try {
      // 1. Check whether GPS is enabled.
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage('ফোনের Location/GPS চালু করুন।');
        return;
      }

      // 2. Check location permission.
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('দূরত্ব দেখতে Location permission দিন।');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'ফোনের Settings থেকে অ্যাপের Location permission চালু করুন।',
        );
        return;
      }

      // 3. Get the customer's current location.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      // 4. Read the vendor's shop coordinates from Firestore.
      // Note: this read requires Firestore Rules to permit it.
      final vendorDoc = await FirebaseFirestore.instance
          .collection('publicShops')
          .doc(item.ownerId.trim())
          .get();

      if (!vendorDoc.exists) {
        showMessage('দোকানদারের Firebase তথ্য পাওয়া যায়নি।');
        return;
      }

      final data = vendorDoc.data();

      if (data == null) {
        showMessage('দোকানের তথ্য পড়া যায়নি।');
        return;
      }

      final lat = data['shopLatitude'];
      final lng = data['shopLongitude'];

      if (lat is! num || lng is! num) {
        showMessage(
          'দোকানদারের GPS লোকেশন Firebase-এ সেভ করা নেই।',
        );
        return;
      }

      final shopLat = lat.toDouble();
      final shopLng = lng.toDouble();

      // 5. Validate the coordinates.
      if (!shopLat.isFinite ||
          !shopLng.isFinite ||
          shopLat < -90 ||
          shopLat > 90 ||
          shopLng < -180 ||
          shopLng > 180) {
        showMessage('দোকানের GPS coordinates সঠিক নয়।');
        return;
      }

      // 6. Calculate the straight-line distance.
      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        shopLat,
        shopLng,
      );

      if (!mounted) return;

      setState(() {
        customerPosition = position;
        shopLatitude = shopLat;
        shopLongitude = shopLng;
        distanceInKm = distanceMeters / 1000;
      });

      showMessage('দোকানের দূরত্ব পাওয়া গেছে।');
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase error: ${e.code} | ${e.message}',
      );

      if (e.code == 'permission-denied') {
        showMessage(
          'Firebase অনুমতি নেই। Firestore Rules পরীক্ষা করুন।',
        );
      } else if (e.code == 'unavailable') {
        showMessage(
          'Firebase সার্ভার পাওয়া যাচ্ছে না। ইন্টারনেট পরীক্ষা করুন।',
        );
      } else {
        showMessage('Firebase সমস্যা: ${e.code}');
      }
    } on TimeoutException {
      showMessage(
        'GPS লোকেশন পেতে সময় লাগছে। আবার চেষ্টা করুন।',
      );
    } catch (e, stackTrace) {
      debugPrint('Shop distance error: $e');
      debugPrintStack(stackTrace: stackTrace);

      showMessage('লোকেশন পেতে সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() {
          loadingLocation = false;
        });
      }
    }
  }

  Future<void> openGoogleMaps() async {
    // Obtain the shop coordinates first if they are not loaded.
    if (shopLatitude == null || shopLongitude == null) {
      await findShopAndDistance();

      if (!mounted ||
          shopLatitude == null ||
          shopLongitude == null) {
        return;
      }
    }

    final destination = '$shopLatitude,$shopLongitude';

    final Uri mapsUri;

    if (customerPosition != null) {
      final origin =
          '${customerPosition!.latitude},'
          '${customerPosition!.longitude}';

      mapsUri = Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'origin': origin,
          'destination': destination,
          'travelmode': 'driving',
        },
      );
    } else {
      mapsUri = Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination': destination,
          'travelmode': 'driving',
        },
      );
    }

    try {
      final launched = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        showMessage('Google Maps খোলা যায়নি।');
      }
    } catch (e) {
      debugPrint('Google Maps error: $e');
      showMessage('Google Maps চালু করতে সমস্যা হয়েছে।');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'পণ্যের বিস্তারিত',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 45,
                      color: Color(0xFF006A4E),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.category,
                    style: const TextStyle(
                      color: Color(0xFF006A4E),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '৳${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item.available
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.available
                          ? '✓ বর্তমানে পাওয়া যাচ্ছে'
                          : '✕ বর্তমানে পাওয়া যাচ্ছে না',
                      style: TextStyle(
                        color: item.available
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Product Description
            const Text(
              'পণ্যের বিবরণ',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item.description.isEmpty
                    ? 'কোনো বিবরণ দেওয়া হয়নি।'
                    : item.description,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Shop Information
            const Text(
              'দোকানের তথ্য',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(
                        Icons.store,
                        color: Color(0xFF006A4E),
                      ),
                    ),
                    title: const Text('দোকানের নাম'),
                    subtitle: Text(
                      item.shopName.isEmpty
                          ? 'দোকানের নাম দেওয়া নেই'
                          : item.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red,
                      ),
                    ),
                    title: const Text('লোকেশন'),
                    subtitle: Text(
                      item.location.isEmpty
                          ? 'লোকেশন দেওয়া নেই'
                          : item.location,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(
                        Icons.phone,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text('ফোন'),
                    subtitle: Text(
                      item.phone.isEmpty
                          ? 'ফোন নম্বর দেওয়া নেই'
                          : item.phone,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Distance and Google Maps
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF006A4E)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions,
                    size: 36,
                    color: Color(0xFF006A4E),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'দোকানটি কত দূরে?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (distanceInKm != null)
                    Text(
                      distanceInKm! < 1
                          ? '${(distanceInKm! * 1000).round()} মিটার দূরে'
                          : '${distanceInKm!.toStringAsFixed(2)} কিমি দূরে',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006A4E),
                      ),
                    )
                  else
                    const Text(
                      'দূরত্ব জানতে বর্তমান লোকেশন ব্যবহার করুন।',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),

                  // Find Distance Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: loadingLocation
                          ? null
                          : findShopAndDistance,
                      icon: loadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        loadingLocation
                            ? 'লোকেশন খোঁজা হচ্ছে...'
                            : 'দূরত্ব দেখুন',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Google Maps Directions Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: loadingLocation
                          ? null
                          : openGoogleMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text(
                        'Google Maps-এ যাওয়ার পথ দেখুন',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006A4E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Order Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: item.available
                    ? () => openOrderScreen(context)
                    : null,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text(
                  'অর্ডার করুন',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Call Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: item.available &&
                        item.phone.trim().isNotEmpty
                    ? () => makePhoneCall(context)
                    : null,
                icon: const Icon(Icons.call),
                label: Text(
                  !item.available
                      ? 'পণ্যটি বর্তমানে নেই'
                      : item.phone.trim().isEmpty
                          ? 'ফোন নম্বর নেই'
                          : 'দোকানে কল করুন',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006A4E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
