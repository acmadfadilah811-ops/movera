import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movera_pelanggan/features/auth/presentation/pages/auth_page.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_event.dart';
import '../bloc/splash_state.dart';
import '../../../../injection_container.dart' as di;
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  double _sliderPosition = 0;
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<SplashBloc>()..add(StartSplashEvent()),
      child: BlocListener<SplashBloc, SplashState>(
        listener: (context, state) {
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.white)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Image.asset('assets/brand/logo_portrait.png', width: 220),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.45,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: TopCurveClipper(),
                  child: Container(
                    color: const Color(0xff0a0a0a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          const SizedBox(height: 110),
                          Text(
                            'Antar-jemput harian?',
                            style: GoogleFonts.poppins(
                              color: const Color(0xff76eb07),
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            "Ayo Mulai",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 48,
                              height: 0.9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            "Mobil listrik, driver karyawan, jadwal pasti.\nCukup satu langganan bulanan.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              double maxWidth = constraints.maxWidth;
                              double handleSize = 60.0;
                              double maxSlide = maxWidth - handleSize - 10; 

                              return Container(
                                height: 70,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xff1a1a1a),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Center(
                                      child: Opacity(
                                        opacity: (1 - (_sliderPosition / maxSlide)).clamp(0, 1),
                                        child: Text(
                                          "Geser untuk mulai",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 5 + _sliderPosition,
                                      child: GestureDetector(
                                        onHorizontalDragUpdate: (details) {
                                          if (!_isUnlocked) {
                                            setState(() {
                                              _sliderPosition += details.delta.dx;
                                              if (_sliderPosition < 0) _sliderPosition = 0;
                                              if (_sliderPosition > maxSlide) _sliderPosition = maxSlide;
                                            });
                                          }
                                        },
                                        onHorizontalDragEnd: (details) {
                                          if (_sliderPosition > maxSlide * 0.8) {
                                            setState(() {
                                              _sliderPosition = maxSlide;
                                              _isUnlocked = true;
                                            });
                                            Future.delayed(const Duration(milliseconds: 200), () {
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(builder: (_) => const AuthPage()),
                                              );
                                            });
                                          } else {
                                            setState(() {
                                              _sliderPosition = 0;
                                            });
                                          }
                                        },
                                        child: Container(
                                          height: handleSize,
                                          width: handleSize,
                                          decoration: const BoxDecoration(
                                            color: Color(0xff76eb07),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isUnlocked ? Icons.check : Icons.arrow_forward_ios_rounded,
                                            color: Colors.black,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 100);
    path.quadraticBezierTo(size.width / 2, -30, 0, 100);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
