// lib/widgets/banner_ad_widget.dart - Reusable banner ad component

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../services/ads_service.dart';
import '../helpers/ad_helper.dart';

/// A reusable widget that properly manages banner ad lifecycle
/// This prevents the "AdWidget already in widget tree" error
class BannerAdWidget extends StatefulWidget {
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? height;
  final bool showBorder;

  const BannerAdWidget({
    super.key,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.height,
    this.showBorder = true,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoading = false;
  bool _hasError = false;
  String _adKey = '';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    if (!AdHelper.canShowBannerAd() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Dispose existing ad
      _bannerAd?.dispose();
      _bannerAd = null;

      // Create new banner ad
      final bannerAd = await AdsService.createNewBannerAd();
      
      if (mounted && bannerAd != null) {
        setState(() {
          _bannerAd = bannerAd;
          _adKey = DateTime.now().millisecondsSinceEpoch.toString();
          _isLoading = false;
          _hasError = false;
        });
        
        if (kDebugMode) print('✅ BannerAdWidget: Ad loaded successfully');
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        
        if (kDebugMode) print('❌ BannerAdWidget: Failed to load ad');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      
      if (kDebugMode) print('❌ BannerAdWidget: Error loading ad: $e');
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: widget.height ?? 50,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        border: widget.showBorder ? Border.all(
          color: widget.borderColor ?? Colors.grey[300]!,
          width: 1,
        ) : null,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: widget.height ?? 50,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[50],
        border: widget.showBorder ? Border.all(
          color: widget.borderColor ?? Colors.grey[200]!,
          width: 1,
        ) : null,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _loadBannerAd,
              child: Text(
                'Tap to retry ad',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdWidget() {
    if (_bannerAd == null) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: widget.height ?? _bannerAd!.size.height.toDouble(),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        border: widget.showBorder ? Border.all(
          color: widget.borderColor ?? Colors.grey[300]!,
          width: 1,
        ) : null,
      ),
      child: AdWidget(
        key: ValueKey(_adKey), // Unique key prevents reuse errors
        ad: _bannerAd!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if ads are disabled
    if (!AdHelper.canShowBannerAd()) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_bannerAd != null) {
      return _buildAdWidget();
    }

    // Fallback case
    return _buildLoadingWidget();
  }
}