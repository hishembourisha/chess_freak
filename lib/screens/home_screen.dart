// File: lib/screens/home_screen.dart - Updated with Sudoku-inspired navigation

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../screens/chess_game_screen.dart';
import '../screens/settings_screen.dart';
import '../services/ads_service.dart';
import '../helpers/ad_helper.dart';
import '../services/chess_save_service.dart';
import '../services/sound_service.dart';
import '../services/vibration_service.dart';
import '../services/chess_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasSavedGame = false;
  Map<String, dynamic>? _savedGameInfo;
  bool _isLoading = false;
  bool _adsRemoved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _checkForSavedGame();
    _loadAdStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      await AdHelper.refreshStatus();
      
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
        AdHelper.debugAdStatus();
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
        _loadAdStatus();
        break;
      default:
        break;
    }
  }

  Future<void> _checkForSavedGame() async {
    try {
      print('🔍 Checking for saved chess game...');
      final hasSaved = await ChessSaveService.hasSavedGame();
      print('📂 Has saved game: $hasSaved');
      
      if (hasSaved) {
        final gameInfo = await ChessSaveService.getSavedGameInfo();
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
                        'CHESS FREAK',
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
                              color: Color(0xFF9E9E9E),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.brown[600],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_esports,
                          size: 150,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (_hasSavedGame && _savedGameInfo != null) ...[
                        Card(
                          elevation: 4,
                          color: Colors.brown.shade50,
                          child: InkWell(
                            onTap: _isLoading ? null : () => _showResumeDialog(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [Colors.brown.withOpacity(0.1), Colors.brown.withOpacity(0.05)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isLoading ? Colors.grey : Colors.brown,
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
                                          _isLoading ? 'Loading...' : 'Resume Chess Game',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _isLoading ? Colors.grey : Colors.brown,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_getDifficultyDisplayName(_savedGameInfo!['difficulty'])} • ${_getTimeAgo(_savedGameInfo!['timestamp'])}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Moves: ${_savedGameInfo!['moveCount']} • Playing as ${_savedGameInfo!['playerColor']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _isLoading ? Colors.grey : Colors.brown,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: _isLoading ? Colors.grey : Colors.brown,
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
                      
                      _buildDifficultyCard(Difficulty.beginner, 'Easy', 'Perfect for learning chess basics', Colors.green, Icons.sentiment_satisfied),
                      const SizedBox(height: 12),
                      _buildDifficultyCard(Difficulty.intermediate, 'Medium', 'Good challenge for casual players', Colors.orange, Icons.sentiment_neutral),
                      const SizedBox(height: 12),
                      _buildDifficultyCard(Difficulty.advanced, 'Hard', 'Challenging for experienced players', Colors.red, Icons.sentiment_very_dissatisfied),
                      const SizedBox(height: 30),
                      
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('Settings'),
                        onPressed: _isLoading ? null : () => _navigateToSettings(),
                      ),
                      const SizedBox(height: 20),
                      
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
                      
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Game Features',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureRow(Icons.speed, '3 AI Difficulty Levels'),
                            _buildFeatureRow(Icons.visibility, 'Move Highlighting'),
                            _buildFeatureRow(Icons.inventory, 'Captured Pieces Display'),
                            _buildFeatureRow(Icons.smart_toy, 'Smart Chess AI'),
                            _buildFeatureRow(Icons.save, 'Auto-save Progress'),
                            _buildFeatureRow(Icons.music_note, 'Sound Effects'),
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

  Widget _buildDifficultyCard(Difficulty difficulty, String displayName, String description, Color color, IconData icon) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: _isLoading ? null : () => _startGame(difficulty),
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
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDifficultySubtext(difficulty),
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

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.brown[600],
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyDisplayName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Easy';
      case Difficulty.intermediate:
        return 'Medium';
      case Difficulty.advanced:
        return 'Hard';
    }
  }

  String _getDifficultySubtext(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Random moves, good for learning';
      case Difficulty.intermediate:
        return 'Basic strategy and tactics';
      case Difficulty.advanced:
        return 'Advanced algorithms and planning';
    }
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    final minutes = diff ~/ (1000 * 60);
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;
    
    if (days > 0) return '$days day${days == 1 ? '' : 's'} ago';
    if (hours > 0) return '$hours hour${hours == 1 ? '' : 's'} ago';
    if (minutes > 0) return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }

  IconData _getDifficultyIcon(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Icons.sentiment_satisfied;
      case Difficulty.intermediate:
        return Icons.sentiment_neutral;
      case Difficulty.advanced:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Colors.green;
      case Difficulty.intermediate:
        return Colors.orange;
      case Difficulty.advanced:
        return Colors.red;
    }
  }

  void _showResumeDialog() {
    if (_savedGameInfo != null && !_isLoading) {
      print('🎮 Showing resume dialog for chess game');
      
      SoundService.playButton();
      VibrationService.buttonPressed();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.save, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Resume Chess Game?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You have a saved chess game in progress.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              // Game details card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getDifficultyIcon(_savedGameInfo!['difficulty']),
                          color: _getDifficultyColor(_savedGameInfo!['difficulty']),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Difficulty: ${_getDifficultyDisplayName(_savedGameInfo!['difficulty'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Last played: ${_getTimeAgo(_savedGameInfo!['timestamp'])}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(Icons.sports_esports, size: 16, color: Colors.brown[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Moves: ${_savedGameInfo!['moveCount']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.person, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Playing as: ${_savedGameInfo!['playerColor']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Would you like to resume this game or start a new one?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                VibrationService.buttonPressed();
                Navigator.pop(context);
                _startNewGameDialog();
              },
              child: const Text('New Game'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                VibrationService.buttonPressed();
                Navigator.pop(context);
                _resumeSavedGame();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  // UPDATED: Use navigation arguments like Sudoku
  Future<void> _resumeSavedGame() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('📂 Loading saved chess game data...');
      
      final savedData = await ChessSaveService.loadGame();
      
      if (savedData != null && mounted) {
        print('✅ Saved chess game loaded successfully');
        print('🎯 Game data: difficulty=${savedData['difficulty']}, gameTime=${savedData['gameTime']}');
        
        SoundService.playButton();
        VibrationService.buttonPressed();
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChessGameScreen(),
            settings: RouteSettings(arguments: {
              'difficulty': savedData['difficulty'],
              'savedGameData': savedData,
            }),
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _checkForSavedGame();
            _loadAdStatus();
          }
        });
      } else {
        print('❌ Failed to load saved chess game data');
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
        title: const Text('New Chess Game'),
        content: const Text('Choose difficulty for your new game:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame(Difficulty.beginner, deleteExisting: true);
            },
            child: const Text('Easy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame(Difficulty.intermediate, deleteExisting: true);
            },
            child: const Text('Medium'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame(Difficulty.advanced, deleteExisting: true);
            },
            child: const Text('Hard'),
          ),
        ],
      ),
    );
  }

  // UPDATED: Use navigation arguments like Sudoku
  void _startGame(Difficulty difficulty, {bool deleteExisting = false}) {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    print('🎮 Starting chess game with difficulty: $difficulty');
    
    if (deleteExisting) {
      ChessSaveService.deleteSavedGame();
    }
    
    SoundService.playButton();
    VibrationService.buttonPressed();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChessGameScreen(),
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
        _loadAdStatus();
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
      _loadAdStatus();
    });
  }
}