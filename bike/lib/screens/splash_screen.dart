import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ────────────────────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _bikeController;
  late AnimationController _textController;
  late AnimationController _taglineController;
  late AnimationController _pulseController;
  Timer? _navigationTimer;

  // Logo pop-in
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  // Bike continuous race
  late Animation<Offset> _bikeSlide;

  // Text reveal
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  // Tagline reveal
  late Animation<double> _taglineFade;

  // Glow pulse on background circle
  late Animation<double> _pulseScale;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // ─── Theme Colors ────────────────────────────────────────────────────────
  static const Color _bgColor = Color(0xFF111111); // 20% Black
  static const Color _primaryRed = Color.fromARGB(255, 188, 0, 16);
  static const Color _accentRed = Color.fromARGB(255, 188, 0, 16);
  static const Color _white = Color(0xFFFFFFFF); // 50% White — text / icon
  static const Color _dimWhite = Color(0xAAFFFFFF); // Tagline

  @override
  void initState() {
    super.initState();

    // 1. Central glow circle pulse (loops forever)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Logo pop-in (0 → 800ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 3. App name slide up (start at 600ms)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // 4. Tagline fade (start at 900ms after logo)
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );

    // 5. Bike races across (after 1.8s delay)
    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _bikeSlide =
        Tween<Offset>(
          begin: const Offset(-3.0, 0.0),
          end: const Offset(3.5, 0.0),
        ).animate(
          CurvedAnimation(
            parent: _bikeController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Logo pop-in
    _logoController.forward();

    // App name slides up just as logo settles
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _textController.forward();

    // Tagline fades in
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _taglineController.forward();

    // Pause, then bike races across WITH sound
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    unawaited(_playBikeSound());
    _bikeController.forward();

    // Navigate after bike finishes based on login status
    _navigationTimer = Timer(const Duration(milliseconds: 2000), _navigate);
  }

  Future<void> _playBikeSound() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/bike_sound.mp3'));
    } catch (error, stackTrace) {
      debugPrint('Unable to play splash sound: $error\n$stackTrace');
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final isLoggedIn = await context.read<AuthProvider>().checkLoginStatus();
    if (!mounted) return;

    final targetScreen = isLoggedIn ? const MainShell() : const LoginScreen();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => targetScreen,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _logoController.dispose();
    _bikeController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // ── Diagonal speed lines (faint) ─────────────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: _SpeedLinePainter()),
            ),
          ),

          // ── CENTER CONTENT ────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Solid glowing circle + icon
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _pulseController,
                  ]),
                  builder: (_, _) {
                    return FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryRed,
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryRed.withValues(alpha: 0.55),
                                  blurRadius: 50,
                                  spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: _accentRed.withValues(alpha: 0.25),
                                  blurRadius: 100,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // App name
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(position: _textSlide, child: child),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'BIKE SQUAD',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 4,
                          color: _white,
                          shadows: [
                            Shadow(
                              color: _primaryRed.withValues(alpha: 0.6),
                              offset: const Offset(0, 4),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Red underline bar (like BicyCart image)
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Tagline
                AnimatedBuilder(
                  animation: _taglineController,
                  builder: (_, child) =>
                      FadeTransition(opacity: _taglineFade, child: child),
                  child: Text(
                    '#Ride together, ride safe',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      color: _dimWhite,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BIKE racing across BELOW the logo ────────────────────────────
          Positioned(
            top: size.height * 0.72,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _bikeController,
              builder: (_, _) {
                return FractionalTranslation(
                  translation: _bikeSlide.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Motion blur trail behind bike
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _primaryRed.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.rotate(
                        angle: 0.12, // slight forward lean
                        child: Icon(
                          Icons.motorcycle,
                          size: 60,
                          color: _primaryRed,
                          shadows: [
                            Shadow(
                              color: _primaryRed.withValues(alpha: 0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Bottom Rider Slogan ─────────────────────────────────────────
          Positioned(
            bottom: 38,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _taglineController,
              builder: (_, child) =>
                  FadeTransition(opacity: _taglineFade, child: child!),
              child: Column(
                children: [
                  Text(
                    '🔥  Born to Ride. Built to Lead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: _white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 1.5,
                        color: _primaryRed.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BIKE SQUAD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          color: _primaryRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 1.5,
                        color: _primaryRed.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Thin red bottom bar ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _primaryRed, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Speed Lines Painter ────────────────────────────────────────────────────
class _SpeedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(99);
    for (int i = 0; i < 20; i++) {
      final y = rnd.nextDouble() * size.height;
      final x = rnd.nextDouble() * size.width;
      final len = 40 + rnd.nextDouble() * 100;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
