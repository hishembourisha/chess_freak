// lib/screens/hint_store_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/iap_service.dart';
import '../services/ad_helper.dart';
import '../services/vibration_service.dart';

class HintStoreScreen extends StatefulWidget {
  const HintStoreScreen({super.key});

  @override
  State<HintStoreScreen> createState() => _HintStoreScreenState();
}

class _HintStoreScreenState extends State<HintStoreScreen> {
  int _hintBalance = 0;
  bool _isLoading = false;

  // Hint packages with pricing - prices will be loaded dynamically
  final List<Map<String, dynamic>> _hintPackages = [
    {
      'hints': 200,
      'productId': 'hint_pack_200',
      'popular': false,
      'description': 'Perfect starter pack',
      'color': Colors.blue,
      'price': 'Loading...', // Will be updated dynamically
    },
    {
      'hints': 500,
      'productId': 'hint_pack_500',
      'popular': true,
      'description': 'Most popular choice',
      'color': Colors.green,
      'price': 'Loading...', // Will be updated dynamically
    },
    {
      'hints': 1000,
      'productId': 'hint_pack_1000',
      'popular': false,
      'description': 'Great value pack',
      'color': Colors.orange,
      'price': 'Loading...', // Will be updated dynamically
    },
    {
      'hints': 2500,
      'productId': 'hint_pack_unlimited',
      'popular': false,
      'description': 'Massive hint pack',
      'color': Colors.purple,
      'price': 'Loading...', // Will be updated dynamically
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHintBalance();
    _loadProductPrices(); // Load real prices from store
  }

  Future<void> _loadHintBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hintBalance = prefs.getInt('hint_balance') ?? 0;
    });
  }

  // Load actual prices from the app store
  Future<void> _loadProductPrices() async {
    try {
      if (!IAPService.isAvailable) {
        // Set fallback prices if IAP not available
        setState(() {
          for (int i = 0; i < _hintPackages.length; i++) {
            _hintPackages[i]['price'] = 'Unavailable';
          }
        });
        return;
      }

      final products = await IAPService.getProducts();
      
      setState(() {
        for (int i = 0; i < _hintPackages.length; i++) {
          final productId = _hintPackages[i]['productId'];
          final product = products.where((p) => p.id == productId).firstOrNull;
          
          if (product != null) {
            _hintPackages[i]['price'] = product.price; // Real localized price
          } else {
            _hintPackages[i]['price'] = 'Price unavailable';
          }
        }
      });
    } catch (e) {
      if (kDebugMode) print('Failed to load product prices: $e');
      // Set fallback prices on error
      setState(() {
        for (int i = 0; i < _hintPackages.length; i++) {
          _hintPackages[i]['price'] = 'Price unavailable';
        }
      });
    }
  }

  Future<void> _purchaseHintPack(Map<String, dynamic> package) async {
    VibrationService.buttonPressed();
    
    setState(() => _isLoading = true);
    
    try {
      if (!IAPService.isAvailable) {
        _showPurchaseNotAvailableDialog();
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Processing purchase of ${package['hints']} hints...'),
              ],
            ),
          ),
        );
      }

      // Call actual IAP service to purchase
      bool purchaseSuccessful = await IAPService.purchaseProduct(package['productId']);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (!mounted) return;
      
    if (purchaseSuccessful) {
      // SAFE: Only proceed if IAP service has already saved the hints
      await _loadHintBalance(); // Reload from what IAP actually saved
      
      // Verify hints were actually added by IAP service
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = prefs.getInt('hint_balance') ?? 0;
      
      if (currentBalance > _hintBalance) {
        // Purchase confirmed - hints were added by IAP service
        setState(() => _hintBalance = currentBalance);
        VibrationService.medium();
        _showPurchaseSuccessDialog(package);
      } else {
        // Purchase failed to complete
        VibrationService.errorEntry();
        _showErrorSnackBar('Purchase failed to complete. Please try again.');
      }
    }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      VibrationService.errorEntry();
      _showErrorSnackBar('Purchase failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPurchaseSuccessDialog(Map<String, dynamic> package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('Purchase Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve successfully purchased ${package['hints']} hints!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'New Balance: $_hintBalance hints',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Added: ${package['hints']} hints',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              VibrationService.buttonPressed();
              Navigator.of(context).pop();
            },
            child: const Text('Continue Playing!'),
          ),
        ],
      ),
    );
  }

  void _showPurchaseNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchases Not Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('In-app purchases are not available on this device or in this environment.'),
            const SizedBox(height: 12),
            const Text('This could be because:'),
            const Text('• Testing on emulator (use real device)'),
            const Text('• App not published on Play Store'),
            const Text('• Google Play Services not available'),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              const Text('Debug Mode: You can simulate purchases for testing.', 
                style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (kDebugMode)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Grant some hints for testing
                await IAPService.debugGrantHints(50);
                await _loadHintBalance(); // Reload balance
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🐛 DEBUG: 50 hints granted for testing'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('Grant Test Hints'),
            ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Helper method to calculate value safely
  String _calculateValue(Map<String, dynamic> package) {
    try {
      final hints = package['hints'] as int;
      final priceString = package['price'] as String;
      
      // Skip calculation if price is still loading or unavailable
      if (priceString == 'Loading...' || 
          priceString == 'Unavailable' || 
          priceString == 'Price unavailable') {
        return '';
      }
      
      // Extract numeric value from price string (works for any currency)
      // Examples: "$3.49" -> 3.49, "£2.99" -> 2.99, "€3,49" -> 3.49
      final cleanPrice = priceString.replaceAll(RegExp(r'[^\d.,]'), ''); // Remove currency symbols
      final numericPrice = double.tryParse(cleanPrice.replaceAll(',', '.')) ?? 0.0;
      
      if (numericPrice > 0) {
        final hintsPerUnit = (hints / numericPrice).round();
        // Extract currency symbol for display
        final currencyMatch = RegExp(r'[^\d.,\s]+').firstMatch(priceString);
        final currency = currencyMatch?.group(0) ?? '';
        return '≈ $hintsPerUnit hints/$currency';
      } else {
        return 'Great value!';
      }
    } catch (e) {
      return 'Great value!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hint Store'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current balance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your Hint Balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_hintBalance hints',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Currency disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prices shown in Euro (€) are for reference. Google Play will charge in your local currency based on your region and payment method.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Section title
                  const Text(
                    'Hint Packages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Hint packages
                  ...List.generate(
                    _hintPackages.length,
                    (index) => _buildHintPackageCard(_hintPackages[index]),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Footer disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchasing Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Hints never expire and carry over between games\n'
                          '• All purchases are final and non-refundable\n'
                          '• Secure payment through Google Play\n'
                          '• Use hints when you need assistance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHintPackageCard(Map<String, dynamic> package) {
    final bool isPopular = package['popular'] as bool;
    final Color color = package['color'] as Color;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Card(
            elevation: isPopular ? 6 : 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isPopular 
                  ? BorderSide(color: color, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _purchaseHintPack(package),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isPopular
                      ? LinearGradient(
                          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${package['hints']} Hints',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              if (isPopular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'POPULAR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            package['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                package['price'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _calculateValue(package),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Purchase button
                    ElevatedButton(
                      onPressed: (_isLoading || package['price'] == 'Loading...') 
                          ? null 
                          : () => _purchaseHintPack(package),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(package['price'] == 'Loading...' ? 'Loading...' : 'Buy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Popular badge
          if (isPopular)
            Positioned(
              top: -4,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}