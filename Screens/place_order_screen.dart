
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/item_model.dart';

class PlaceOrderScreen extends StatefulWidget {
  final ItemModel item;

  const PlaceOrderScreen({
    super.key,
    required this.item,
  });

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  bool _isSubmitting = false;

  int get _quantity {
    return int.tryParse(
          _toEnglishDigits(_quantityController.text.trim()),
        ) ??
        1;
  }

  double get _totalPrice => widget.item.price * _quantity;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('অর্ডার করতে আগে লগইন করুন।');
      return;
    }

    if (widget.item.id.isEmpty) {
      _showMessage('পণ্যের পরিচয় পাওয়া যায়নি। আবার পণ্যটি খুঁজুন।');
      return;
    }

    final quantity = _quantity;

    if (quantity < 1 || quantity > 1000) {
      _showMessage('পণ্যের পরিমাণ ১ থেকে ১০০০-এর মধ্যে হতে হবে।');
      return;
    }

    final customerName = _nameController.text.trim();

    final phone = _toEnglishDigits(
      _phoneController.text.trim(),
    ).replaceAll(RegExp(r'[\s\-+]'), '');

    final address = _addressController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final productRef = firestore
          .collection('products')
          .doc(widget.item.id);

      final orderRef = firestore.collection('orders').doc();

      // Notification-এর জন্য আলাদা document reference।
      final notificationRef =
          firestore.collection('notifications').doc();

      await firestore.runTransaction((transaction) async {
        // সর্বশেষ পণ্যের তথ্য পড়া।
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception('পণ্যটি আর পাওয়া যাচ্ছে না।');
        }

        final productData = productSnapshot.data();

        if (productData == null) {
          throw Exception('পণ্যের তথ্য পাওয়া যায়নি।');
        }

        final vendorId =
            (productData['ownerId'] ?? '').toString().trim();

        if (vendorId.isEmpty) {
          throw Exception('বিক্রেতার তথ্য পাওয়া যায়নি।');
        }

        if (vendorId == user.uid) {
          throw Exception('নিজের দোকানের পণ্য অর্ডার করা যাবে না।');
        }

        if (productData['available'] != true) {
          throw Exception('পণ্যটি বর্তমানে পাওয়া যাচ্ছে না।');
        }

        final productName =
            (productData['name'] ?? '').toString().trim();

        final shopName =
            (productData['shopName'] ?? '').toString().trim();

        final priceValue = productData['price'];
        final stockValue = productData['stock'];

        if (priceValue is! num || priceValue < 0) {
          throw Exception('পণ্যের দাম সঠিক নয়।');
        }

        if (stockValue is! int || stockValue < 0) {
          throw Exception(
            'পণ্যের স্টক সঠিক নেই। বিক্রেতাকে স্টক আপডেট করতে বলুন।',
          );
        }

        if (stockValue < quantity) {
          throw Exception(
            'পর্যাপ্ত স্টক নেই। বর্তমানে আছে $stockValue টি।',
          );
        }

        if (productName.isEmpty || shopName.isEmpty) {
          throw Exception('পণ্যের বা দোকানের তথ্য অসম্পূর্ণ।');
        }

        final price = priceValue.toDouble();
        final remainingStock = stockValue - quantity;

        // পণ্যের স্টক আপডেট।
        transaction.update(productRef, {
          'stock': remainingStock,
          'available': remainingStock > 0,
          'lastOrderId': orderRef.id,
        });

        // অর্ডার সংরক্ষণ।
        transaction.set(orderRef, {
          'orderId': orderRef.id,
          'productId': productSnapshot.id,
          'productName': productName,
          'vendorId': vendorId,
          'shopName': shopName,
          'customerId': user.uid,
          'customerName': customerName,
          'phone': phone,
          'address': address,
          'quantity': quantity,
          'price': price,
          'totalPrice': price * quantity,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // বিক্রেতার জন্য Notification সংরক্ষণ।
        transaction.set(notificationRef, {
          'userId': vendorId,
          'title': 'নতুন অর্ডার এসেছে!',
          'body':
              '$customerName আপনার দোকান থেকে $productName অর্ডার করেছেন।',
          'type': 'new_order',
          'orderId': orderRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'আপনার অর্ডার সফলভাবে পাঠানো হয়েছে।',
          ),
          backgroundColor: Color(0xFF006A4E),
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      debugPrint(
        'Order Firebase error: ${e.code} - ${e.message}',
      );

      if (!mounted) return;

      if (e.code == 'permission-denied') {
        _showMessage(
          'অর্ডার অনুমোদিত হয়নি। Firestore Security Rules '
          'আপডেট ও যাচাই করতে হবে।',
        );
      } else if (e.code == 'unavailable') {
        _showMessage(
          'ইন্টারনেট সংযোগ পাওয়া যাচ্ছে না। আবার চেষ্টা করুন।',
        );
      } else {
        _showMessage(
          'অর্ডার পাঠানো যায়নি: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst(
            'Exception: ',
            '',
          );

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('অর্ডার করুন'),
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 40,
                    color: Color(0xFF006A4E),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('দোকান: ${widget.item.shopName}'),
                  const SizedBox(height: 6),
                  Text(
                    'একক মূল্য: '
                    '৳${widget.item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF006A4E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ডেলিভারির তথ্য',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _nameController,
              label: 'আপনার নাম',
              hint: 'সম্পূর্ণ নাম লিখুন',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'আপনার নাম লিখুন';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _phoneController,
              label: 'মোবাইল নম্বর',
              hint: '01XXXXXXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final phone = _toEnglishDigits(
                  value?.trim() ?? '',
                ).replaceAll(RegExp(r'[\s\-+]'), '');

                if (!RegExp(r'^\d{10,14}$').hasMatch(phone)) {
                  return 'সঠিক মোবাইল নম্বর লিখুন';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _addressController,
              label: 'সম্পূর্ণ ঠিকানা',
              hint: 'এলাকা, রাস্তা ও বাড়ির ঠিকানা',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().length < 5) {
                  return 'সম্পূর্ণ ঠিকানা লিখুন';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _quantityController,
              label: 'পরিমাণ',
              hint: 'কতটি কিনবেন?',
              icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                final quantity = int.tryParse(
                  _toEnglishDigits(value?.trim() ?? ''),
                );

                if (quantity == null || quantity < 1) {
                  return 'কমপক্ষে ১টি পণ্য নির্বাচন করুন';
                }

                if (quantity > 1000) {
                  return 'পরিমাণ ১০০০-এর কম হতে হবে';
                }

                return null;
              },
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'সর্বমোট মূল্য',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '৳${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A4E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _placeOrder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  _isSubmitting
                      ? 'অর্ডার পাঠানো হচ্ছে...'
                      : 'অর্ডার নিশ্চিত করুন',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006A4E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF006A4E),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _toEnglishDigits(String value) {
    const bangla = '০১২৩৪৫৬৭৮৯';
    const english = '0123456789';

    for (int i = 0; i < bangla.length; i++) {
      value = value.replaceAll(
        bangla[i],
        english[i],
      );
    }

    return value;
  }
}

