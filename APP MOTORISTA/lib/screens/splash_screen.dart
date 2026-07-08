import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main timeline — 4000ms, plays once
  late AnimationController _main;
  // Pulse loop — glow breathing effect
  late AnimationController _pulse;
  // Sparkle rotation loop
  late AnimationController _rotate;

  late Animation<double> _bgGlow;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _ringFade;
  late Animation<double> _sparkFade;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _lineWidth;
  late Animation<double> _subtitleFade;
  late Animation<double> _progressFill;
  late Animation<double> _screenFade;

  late Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000));

    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _rotate = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..repeat();

    _bgGlow = _interval(0.0, 0.45, Curves.easeOut);

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _main,
        curve: const Interval(0.04, 0.42, curve: Curves.elasticOut)));

    _logoFade = _interval(0.04, 0.28, Curves.easeOut);

    _ringFade = _interval(0.12, 0.50, Curves.easeOut);

    _sparkFade = _interval(0.18, 0.60, Curves.easeIn);

    _titleSlide = Tween<double>(begin: 48.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _main,
            curve: const Interval(0.40, 0.60, curve: Curves.easeOutCubic)));

    _titleFade = _interval(0.40, 0.58, Curves.easeOut);

    _lineWidth = _interval(0.54, 0.70, Curves.easeOut);

    _subtitleFade = _interval(0.60, 0.74, Curves.easeOut);

    _progressFill = _interval(0.68, 0.88, Curves.easeInOut);

    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _main,
        curve: const Interval(0.90, 1.0, curve: Curves.easeIn)));

    _pulseGlow =
        Tween<double>(begin: 0.30, end: 0.70).animate(_pulse);

    _main.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  Animation<double> _interval(double t0, double t1, Curve curve) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _main, curve: Interval(t0, t1, curve: curve)));
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    _rotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    const gold = Color(0xFFF07000); // ember (dark)
    const goldDark = Color(0xFFF07000); // ember-bright (dark)

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _pulse, _rotate]),
        builder: (context, _) {
          return Opacity(
            opacity: _screenFade.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Radial background glow ──────────────────────────────
                Center(
                  child: Opacity(
                    opacity: _bgGlow.value * 0.9,
                    child: Container(
                      width: sw * 1.6,
                      height: sw * 1.6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x22D4AF37),
                            Color(0x00000000),
                          ],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Main content ────────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo area ──────────────────────────────────────
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing halo
                            Opacity(
                              opacity: _ringFade.value * _pulseGlow.value * 0.5,
                              child: Container(
                                width: 186,
                                height: 186,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: gold, width: 0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          gold.withValues(alpha: 0.20),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Rotating sparkle dots
                            Opacity(
                              opacity: _sparkFade.value,
                              child: Transform.rotate(
                                angle: _rotate.value * 2 * math.pi,
                                child: const _SparkleRing(
                                    radius: 88, count: 8, size: 4),
                              ),
                            ),

                            // Counter-rotating smaller dots
                            Opacity(
                              opacity: _sparkFade.value * 0.5,
                              child: Transform.rotate(
                                angle:
                                    -_rotate.value * 2 * math.pi * 1.7,
                                child: const _SparkleRing(
                                    radius: 76, count: 12, size: 2.5),
                              ),
                            ),

                            // Middle ring (static, pulsing opacity)
                            Opacity(
                              opacity:
                                  _ringFade.value * _pulseGlow.value * 0.35,
                              child: Container(
                                width: 152,
                                height: 152,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: gold.withValues(alpha: 0.6),
                                      width: 1),
                                ),
                              ),
                            ),

                            // Logo circle
                            Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoFade.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [gold, goldDark],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gold.withValues(
                                            alpha: 0.28 +
                                                _pulseGlow.value * 0.28),
                                        blurRadius: 40 +
                                            _pulseGlow.value * 12,
                                        spreadRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: gold.withValues(alpha: 0.14),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(18),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── TROCO SEGURO ────────────────────────────────────
                      Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: const Text(
                            'TROCO SEGURO',
                            style: TextStyle(
                              color: gold,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Gold separator line expanding from center ───────
                      FractionallySizedBox(
                        widthFactor: 0.55,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            widthFactor: _lineWidth.value,
                            child: Container(
                              height: 1.5,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    gold,
                                    goldDark,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.3, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── MOTORISTA ───────────────────────────────────────
                      Opacity(
                        opacity: _subtitleFade.value,
                        child: Text(
                          'M O T O R I S T A',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 5.0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 64),

                      // ── Progress bar ────────────────────────────────────
                      Opacity(
                        opacity: _titleFade.value,
                        child: Column(
                          children: [
                            Container(
                              width: 160,
                              height: 2,
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressFill.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(
                                      colors: [gold, goldDark],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            gold.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: _subtitleFade.value * 0.6,
                              child: Text(
                                'A carregar...',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.30),
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Dots arranged in a circle at given radius
class _SparkleRing extends StatelessWidget {
  final double radius;
  final int count;
  final double size;
  const _SparkleRing(
      {required this.radius, required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF07000); // ember (dark)
    return SizedBox(
      width: radius * 2 + size,
      height: radius * 2 + size,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final angle = (2 * math.pi / count) * i;
          final isLarge = i % 3 == 0;
          return Transform.translate(
            offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
            child: Container(
              width: isLarge ? size * 1.5 : size,
              height: isLarge ? size * 1.5 : size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: isLarge ? 0.85 : 0.45),
                boxShadow: isLarge
                    ? [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.6),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
