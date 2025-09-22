import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ✅ add this
import 'first_page.dart'; // Import your FirstPage here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ✅ proper config
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupPage(),
    );
  }
}

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FirstPage()),
          );
        },
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'assets/admin_start.jpg',
                  fit: BoxFit.contain,
                  height: 550,
                ),
              ),
            ),

            // Gradient overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5F5F5), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Glowing logo
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: const Center(child: GlowingLogo()),
            ),
          ],
        ),
      ),
    );
  }
}

class GlowingLogo extends StatefulWidget {
  const GlowingLogo({super.key});

  @override
  State<GlowingLogo> createState() => _GlowingLogoState();
}

class _GlowingLogoState extends State<GlowingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 9))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.5 + 2.0 * _controller.value, 0),
              end: Alignment(-0.7 + 2.0 * _controller.value, 0),
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.4, 0.5, 0.6],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Image.asset(
            'assets/smilesstone_logo2.png',
            height: 100,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
