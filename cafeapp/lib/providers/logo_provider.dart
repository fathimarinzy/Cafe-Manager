import 'package:flutter/material.dart';
import '../services/logo_service.dart';

class LogoProvider with ChangeNotifier {
  bool _hasLogo = false;
  String? _logoPath;
  int _lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

  bool get hasLogo {
    debugPrint('🔍 LogoProvider: hasLogo getter called - $_hasLogo');
    return _hasLogo;
  }
  
  String? get logoPath {
    debugPrint('🔍 LogoProvider: logoPath getter called - $_logoPath');
    return _logoPath;
  }
  
  int get lastUpdateTimestamp {
    debugPrint('🔍 LogoProvider: timestamp getter called - $_lastUpdateTimestamp');
    return _lastUpdateTimestamp;
  }

  LogoProvider() {
    debugPrint('🚀 LogoProvider: Constructor called');
    _loadLogoState();
  }

  Future<void> _loadLogoState() async {
    debugPrint('📥 LogoProvider: _loadLogoState START');
    
    _hasLogo = await LogoService.hasLogo();
    _logoPath = await LogoService.getLogoPath();
    _lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
    
    debugPrint('📥 LogoProvider: _loadLogoState DONE');
    debugPrint('   hasLogo: $_hasLogo');
    debugPrint('   logoPath: $_logoPath');
    debugPrint('   timestamp: $_lastUpdateTimestamp');

   // CRITICAL FIX: Clear image cache when logo changes
    if (_logoPath != null) {
      // Clear the specific image from cache
      await _clearImageCache();
    }
    debugPrint('🔔 LogoProvider: Calling notifyListeners()');
    notifyListeners();
    debugPrint('✅ LogoProvider: notifyListeners() completed');
  }

  Future<void> updateLogo() async {
    debugPrint('🔄 LogoProvider: updateLogo() called');
    await _loadLogoState();
    debugPrint('✅ LogoProvider: updateLogo() completed');
  }

  Future<void> removeLogo() async {
    debugPrint('🗑️ LogoProvider: removeLogo() called');
    await LogoService.deleteLogo();
    await _loadLogoState();
    debugPrint('✅ LogoProvider: removeLogo() completed');
  }

  Future<void> refresh() async {
    debugPrint('🔄 LogoProvider: refresh() called');
    await _loadLogoState();
    debugPrint('✅ LogoProvider: refresh() completed');
  }

  // Clear image cache for the logo file
  Future<void> _clearImageCache() async {
    try {
      // Clear the entire image cache to ensure logo updates
      imageCache.clear();
      imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }
}