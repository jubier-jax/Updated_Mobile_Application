
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/item_model.dart';
import '../services/product_service.dart';
import 'search_result_screen.dart';
import 'add_sample_products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController =
      TextEditingController();

  final FocusNode searchFocusNode = FocusNode();
  final ProductService productService = ProductService();

  String selectedCategory = 'সব';
  String selectedLocation = 'চাঁদপুর সদর';
  String searchQuery = '';

  bool showSuggestions = false;
  bool isGettingLocation = false;

  Position? currentPosition;

  final List<String> categories = [
    'সব',
    'খাবার',
    'ওষুধ',
    'ইলেকট্রনিক্স',
    'মুদি',
    'কাপড়',
    'সেবা',
  ];

  final List<String> locations = [
    'চাঁদপুর সদর',
    'হাজীগঞ্জ',
    'ফরিদগঞ্জ',
    'মতলব উত্তর',
    'মতলব দক্ষিণ',
    'কচুয়া',
    'শাহরাস্তি',
  ];

  static const Map<String, String> searchAliases = {
    'rui': 'রুই',
    'rohu': 'রুই',
    'mach': 'মাছ',
    'maach': 'মাছ',
    'taja': 'তাজা',
    'taza': 'তাজা',
    'oshudh': 'ওষুধ',
    'osudh': 'ওষুধ',
    'medicine': 'ওষুধ',
    'paracetamol': 'paracetamol',
    'dokan': 'দোকান',
    'dokaan': 'দোকান',
    'notun': 'নতুন',
    'natun': 'নতুন',
    'khaddo': 'খাবার',
    'khabar': 'খাবার',
    'jama': 'কাপড়',
    'kapor': 'কাপড়',
    'charger': 'charger',
  };

  String normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String translateSearch(String value) {
    final normalized = normalize(value);

    if (searchAliases.containsKey(normalized)) {
      return searchAliases[normalized]!;
    }

    return normalized.split(' ').map((word) {
      return searchAliases[word] ?? word;
    }).join(' ');
  }

  bool matchesText(String source, String query) {
    final normalizedSource = normalize(source);
    final normalizedQuery = normalize(query);

    if (normalizedQuery.isEmpty) return true;

    final translatedQuery = translateSearch(normalizedQuery);

    return normalizedSource.contains(normalizedQuery) ||
        normalizedSource.contains(translatedQuery) ||
        normalizedQuery.split(' ').every((word) {
          final translatedWord = searchAliases[word] ?? word;

          return normalizedSource.contains(word) ||
              normalizedSource.contains(translatedWord);
        });
  }

  bool matchesLocation(ItemModel item) {
    return item.location.trim() == selectedLocation.trim();
  }

  List<ItemModel> filterProducts(
    List<ItemModel> products, {
    String query = '',
    String? category,
  }) {
    return products.where((item) {
      final matchesSearch = query.trim().isEmpty ||
          matchesText(item.name, query) ||
          matchesText(item.category, query) ||
          matchesText(item.shopName, query) ||
          matchesText(item.description, query);

      final activeCategory = category ?? selectedCategory;

      final matchesCategory =
          activeCategory == 'সব' ||
          item.category == activeCategory;

      return matchesSearch &&
          matchesCategory &&
          matchesLocation(item) &&
          item.available;
    }).toList();
  }

  // GPS থেকে বর্তমান অবস্থান নেওয়া।
  Future<void> getCurrentLocation() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        await showLocationMessage(
          'ফোনের Location/GPS চালু করুন।',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        await showLocationMessage(
          'লোকেশন ব্যবহারের অনুমতি দেওয়া হয়নি।',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        await showLocationSettingsMessage();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Color(0xFF006A4E),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text('আপনার বর্তমান লোকেশন'),
                ),
              ],
            ),
            content: SelectableText(
              'Latitude: ${position.latitude}\n'
              'Longitude: ${position.longitude}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('ঠিক আছে'),
              ),
            ],
          );
        },
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;

      await showLocationMessage(
        'ফোনের GPS চালু করে আবার চেষ্টা করুন।',
      );
    } catch (e) {
      if (!mounted) return;

      await showLocationMessage(
        'লোকেশন পাওয়া যায়নি। আবার চেষ্টা করুন।',
      );

      debugPrint('Location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  Future<void> showLocationMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> showLocationSettingsMessage() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('লোকেশনের অনুমতি প্রয়োজন'),
          content: const Text(
            'ফোনের App Settings থেকে এই অ্যাপের '
            'Location permission চালু করুন।',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Geolocator.openAppSettings();
              },
              child: const Text('Settings খুলুন'),
            ),
          ],
        );
      },
    );
  }

  void searchItems(
    List<ItemModel> products, {
    String? query,
  }) {
    final text = (query ?? searchController.text).trim();

    setState(() {
      showSuggestions = false;
      searchQuery = text;
    });

    searchFocusNode.unfocus();

    final results = filterProducts(
      products,
      query: text,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultScreen(
          results: results,
        ),
      ),
    );
  }

  void selectSuggestion(
    ItemModel item,
    List<ItemModel> products,
  ) {
    searchController.text = item.name;

    searchItems(
      products,
      query: item.name,
    );
  }

  void searchByCategory(
    String category,
    List<ItemModel> products,
  ) {
    setState(() {
      selectedCategory = category;
      showSuggestions = false;
    });

    searchFocusNode.unfocus();

    final results = filterProducts(
      products,
      query: searchController.text,
      category: category,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultScreen(
          results: results,
        ),
      ),
    );
  }

  void openSampleProductsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSampleProductsScreen(),
      ),
    );
  }

  List<ItemModel> getSuggestions(
    List<ItemModel> products,
  ) {
    final query = searchController.text.trim();

    if (query.isEmpty) return [];

    final matches = products.where((item) {
      return matchesText(item.name, query) ||
          matchesText(item.shopName, query) ||
          matchesText(item.category, query) ||
          matchesText(item.description, query);
    }).toList();

    final seen = <String>{};
    final uniqueMatches = <ItemModel>[];

    for (final item in matches) {
      final key = '${item.name}|${item.shopName}';

      if (seen.add(key)) {
        uniqueMatches.add(item);
      }
    }

    return uniqueMatches.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ItemModel>>(
      stream: productService.getProducts(),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          body: SafeArea(
            child: _buildBody(snapshot),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ItemModel>> snapshot,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 55,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'পণ্য লোড করা যায়নি',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Firebase Firestore Rules এবং '
                'ইন্টারনেট সংযোগ পরীক্ষা করুন।',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
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
          color: Color(0xFF006A4E),
        ),
      );
    }

    final products = snapshot.data ?? [];
    final suggestions = getSuggestions(products);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF006A4E),
                  Color(0xFF00A878),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'কাছে কোথায় আছে?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'আপনার প্রয়োজনীয় পণ্য বা সেবা খুঁজে নিন',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 22),

                // Search box ও suggestions
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'পণ্য বা দোকানের নাম লিখুন',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF006A4E),
                          ),
                          suffixIcon:
                              searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        searchController.clear();

                                        setState(() {
                                          searchQuery = '';
                                          showSuggestions = false;
                                        });
                                      },
                                    ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                            showSuggestions =
                                value.trim().isNotEmpty;
                          });
                        },
                        onTap: () {
                          if (searchController.text
                              .trim()
                              .isNotEmpty) {
                            setState(() {
                              showSuggestions = true;
                            });
                          }
                        },
                        onSubmitted: (_) {
                          searchItems(products);
                        },
                      ),
                      if (showSuggestions &&
                          searchQuery.trim().isNotEmpty)
                        _buildSuggestions(
                          suggestions,
                          products,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // এলাকার Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLocation,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF006A4E),
                      ),
                      items: locations.map((location) {
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(location),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedLocation = value;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // GPS Location button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isGettingLocation
                        ? null
                        : getCurrentLocation,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      isGettingLocation
                          ? 'লোকেশন নেওয়া হচ্ছে...'
                          : currentPosition == null
                              ? 'আমার বর্তমান লোকেশন'
                              : 'লোকেশন পাওয়া গেছে',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      side: const BorderSide(
                        color: Colors.white70,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                if (currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'GPS: ${currentPosition!.latitude.toStringAsFixed(5)}, '
                    '${currentPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => searchItems(products),
                    icon: const Icon(Icons.search),
                    label: const Text(
                      'খুঁজুন',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openSampleProductsScreen,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Sample Products যোগ করুন'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006A4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'ক্যাটাগরি নির্বাচন করুন',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      searchByCategory(category, products);
                    },
                    selectedColor: const Color(0xFF00A878),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'জনপ্রিয় ক্যাটাগরি',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _categoryCard(
                  'খাবার',
                  Icons.restaurant,
                  const Color(0xFFFF6B6B),
                  products,
                ),
                _categoryCard(
                  'ওষুধ',
                  Icons.medication,
                  const Color(0xFF4D96FF),
                  products,
                ),
                _categoryCard(
                  'মুদি',
                  Icons.shopping_basket,
                  const Color(0xFFFFA94D),
                  products,
                ),
                _categoryCard(
                  'কাপড়',
                  Icons.checkroom,
                  const Color(0xFFB197FC),
                  products,
                ),
                _categoryCard(
                  'ইলেকট্রনিক্স',
                  Icons.devices,
                  const Color(0xFF20C997),
                  products,
                ),
                _categoryCard(
                  'সেবা',
                  Icons.handyman,
                  const Color(0xFFFF8787),
                  products,
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    List<ItemModel> suggestions,
    List<ItemModel> products,
  ) {
    if (suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'কোনো মিল পাওয়া যায়নি',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE6E6E6)),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final item = suggestions[index];

          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE1F4EC),
              child: Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF006A4E),
              ),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${item.shopName} • ৳${item.price.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(
              Icons.north_west,
              size: 18,
              color: Color(0xFF006A4E),
            ),
            onTap: () => selectSuggestion(item, products),
          );
        },
      ),
    );
  }

  Widget _categoryCard(
    String title,
    IconData icon,
    Color color,
    List<ItemModel> products,
  ) {
    return InkWell(
      onTap: () => searchByCategory(title, products),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
            ),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }
}
