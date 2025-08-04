// lib/screens/home_screen.dart - Fixed for Remove Ads users with proper state management
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/screens/settings_screen.dart';
import 'package:sudoku_app/services/ads_service.dart';
import 'package:sudoku_app/services/ad_helper.dart'; // For Remove Ads logic
import 'package:sudoku_app/services/sudoku_generator.dart';
import 'package:sudoku_app/services/game_save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../widgets/resume_game_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasSavedGame = false;
  Map<String, dynamic>? _savedGameInfo;
  bool _isLoading = false;
  bool _adsRemoved = false; // ADDED: Track ads status

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _checkForSavedGame();
    _loadAdStatus(); // ADDED: Load ad status
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ADDED: Load ad status when screen initializes
  Future<void> _loadAdStatus() async {
    try {
      await AdHelper.refreshStatus();
      if (mounted) {
        setState(() {
          _adsRemoved = !AdHelper.shouldShowAds();
        });
      }
    } catch (e) {
      print('Error loading ad status: $e');
    }
  }

  Future<void> _initializeServices() async {
    try {
      // FIXED: Refresh ad status before initializing ads
      await AdHelper.refreshStatus();
      
      // Only show banner ads for free users
      if (AdHelper.canShowBannerAd()) {
        await AdsService.showBannerAd();
        print('✅ Banner ad initialized for free user');
      } else {
        print('🚫 Banner ad skipped - user has Remove Ads');
      }
      
      await VibrationService.initialize();
      
      if (mounted) {
        AdsService.debugAdConfiguration();
        SoundService.debugSoundState();
        AdHelper.debugAdStatus(); // ADDED: Debug ad status
      }
    } catch (e) {
      print('❌ Error initializing services in HomeScreen: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle changed to: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        print('⏸️ Pausing background music due to app lifecycle');
        SoundService.pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        print('▶️ Attempting to resume background music due to app lifecycle');
        if (SoundService.isMusicEnabled) {
          SoundService.resumeBackgroundMusic();
        }
        _checkForSavedGame();
        // ADDED: Refresh ad status when app resumes (in case user made purchase)
        _loadAdStatus();
        break;
      default:
        break;
    }
  }

  Future<void> _checkForSavedGame() async {
    try {
      print('🔍 Checking for saved game...');
      final hasSaved = await GameSaveService.hasSavedGame();
      print('📂 Has saved game: $hasSaved');
      
      if (hasSaved) {
        final gameInfo = await GameSaveService.getSavedGameInfo();
        print('📊 Game info: $gameInfo');
        
        if (mounted) {
          setState(() {
            _hasSavedGame = true;
            _savedGameInfo = gameInfo;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasSavedGame = false;
            _savedGameInfo = null;
          });
        }
      }
    } catch (e) {
      print('❌ Error checking for saved game: $e');
      if (mounted) {
        setState(() {
          _hasSavedGame = false;
          _savedGameInfo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SUDOKU FREAK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.black87,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Image.asset(
                        'assets/icon/icon_in_app.png',
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.grid_3x3,
                            size: 150,
                            color: Colors.blue.shade300,
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Resume game button (if saved game exists)
                      if (_hasSavedGame && _savedGameInfo != null) ...[
                        Card(
                          elevation: 4,
                          color: Colors.blue.shade50,
                          child: InkWell(
                            onTap: _isLoading ? null : () => _showResumeDialog(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [Colors.blue.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isLoading ? Colors.grey : Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _isLoading 
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isLoading ? 'Loading...' : 'Resume Game',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _isLoading ? Colors.grey : Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_savedGameInfo!['difficulty']} • ${GameSaveService.getTimeAgo(_savedGameInfo!['timestamp'])}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Hints: ${_savedGameInfo!['hintsUsed']} • Errors: ${_savedGameInfo!['errorCount']}/3',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _isLoading ? Colors.grey : Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: _isLoading ? Colors.grey : Colors.blue,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                                        
                      const Text(
                        'CHOOSE YOUR CHALLENGE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Difficulty buttons
                      _buildDifficultyCard('easy', 'Easy', Colors.green, Icons.sentiment_satisfied),
                      const SizedBox(height: 12),
                      _buildDifficultyCard('medium', 'Medium', Colors.orange, Icons.sentiment_neutral),
                      const SizedBox(height: 12),
                      _buildDifficultyCard('hard', 'Hard', Colors.red, Icons.sentiment_very_dissatisfied),
                      const SizedBox(height: 30),
                      
                      // Secondary buttons
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('Settings'),
                        onPressed: _isLoading ? null : () => _navigateToSettings(),
                      ),
                      const SizedBox(height: 12),
                      
                      // FIXED: Only show "Watch Ad for Hint" for free users
                      if (AdHelper.canShowRewardedAd())
                        OutlinedButton.icon(
                          icon: const Icon(Icons.lightbulb_outline),
                          label: const Text('Watch Ad for Hint'),
                          onPressed: _isLoading ? null : () => _watchAdForHint(),
                        ),
                      
                      // ADDED: Show purchase hint option for paid users
                      if (!AdHelper.canShowRewardedAd())
                        OutlinedButton.icon(
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Buy Hints'),
                          onPressed: _isLoading ? null : () => _navigateToSettings(),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // ADDED: Show Remove Ads status for paid users
                      if (_adsRemoved)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Ad-Free Experience Active',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // FIXED: Only show banner ad for free users
          if (AdHelper.canShowBannerAd()) _buildBannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildBannerAdWidget() {
    final bannerAd = AdsService.bannerAd;
    
    if (bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: bannerAd.size.width.toDouble(),
        height: bannerAd.size.height.toDouble(),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: AdWidget(ad: bannerAd),
      );
    }
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: const Center(
        child: Text(
          'Ad Loading...',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(String difficultyKey, String displayName, Color color, IconData icon) {
    final diffInfo = SudokuGenerator.getDifficultyInfo(difficultyKey);
    final clues = 81 - diffInfo['cellsToRemove'];
    
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: _isLoading ? null : () => _startGame(difficultyKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isLoading ? Colors.grey : color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diffInfo['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$clues starting clues',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isLoading ? Colors.grey : color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: _isLoading ? Colors.grey : color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResumeDialog() {
    if (_savedGameInfo != null && !_isLoading) {
      print('🎮 Showing resume dialog for: ${_savedGameInfo!['difficulty']}');
      
      SoundService.playButton();
      VibrationService.buttonPressed();
      
      ResumeGameDialog.show(
        context,
        gameInfo: _savedGameInfo!,
        onResumeGame: () => _resumeSavedGame(),
        onNewGame: () => _startNewGameDialog(),
      );
    } else {
      print('⚠️ Cannot show resume dialog - loading: $_isLoading, savedGameInfo: $_savedGameInfo');
    }
  }

  Future<void> _resumeSavedGame() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('📂 Loading saved game data...');
      
      final savedData = await GameSaveService.loadGame();
      
      if (savedData != null && mounted) {
        print('✅ Saved game loaded successfully');
        print('🎯 Game data: difficulty=${savedData['difficulty']}, gameTime=${savedData['gameTime']}');
        
        SoundService.playButton();
        VibrationService.buttonPressed();
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GameScreen(),
            settings: RouteSettings(arguments: {
              'difficulty': savedData['difficulty'],
              'savedData': savedData,
            }),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _checkForSavedGame();
            _loadAdStatus(); // ADDED: Refresh ad status when returning
          }
        });
      } else {
        print('❌ Failed to load saved game data');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load saved game'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error resuming saved game: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startNewGameDialog() {
    if (_isLoading) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Game'),
        content: const Text('Choose difficulty for your new game:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame('easy', deleteExisting: true);
            },
            child: const Text('Easy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame('medium', deleteExisting: true);
            },
            child: const Text('Medium'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame('hard', deleteExisting: true);
            },
            child: const Text('Hard'),
          ),
        ],
      ),
    );
  }

  void _startGame(String difficulty, {bool deleteExisting = false}) {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    print('🎮 Starting game with difficulty: $difficulty');
    
    if (deleteExisting) {
      GameSaveService.deleteSavedGame();
    }
    
    SoundService.playButton();
    VibrationService.buttonPressed();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GameScreen(),
        settings: RouteSettings(arguments: {
          'difficulty': difficulty,
        }),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _checkForSavedGame();
        _loadAdStatus(); // ADDED: Refresh ad status when returning
      }
    });
  }

  void _navigateToSettings() {
    if (_isLoading) return;
    
    VibrationService.buttonPressed();
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) {
      // ADDED: Refresh ad status when returning from settings (in case user purchased Remove Ads)
      _loadAdStatus();
    });
  }

  // FIXED: Only allow rewarded ads for free users
  void _watchAdForHint() async {
    if (_isLoading || !AdHelper.canShowRewardedAd()) return;
    
    VibrationService.buttonPressed();
    
    try {
      await AdsService.showRewardedAd(onReward: () async {
        if (!mounted) return;
        
        final prefs = await SharedPreferences.getInstance();
        final currentBalance = prefs.getInt('hint_balance') ?? 0;
        await prefs.setInt('hint_balance', currentBalance + 1);
        
        VibrationService.medium();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You earned 1 hint! New balance: ${currentBalance + 1}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      
      VibrationService.errorEntry();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load ad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}