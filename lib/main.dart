import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'owner_dashboard.dart';
import 'cust_dashboard.dart';
import 'admin_dashboard.dart';
import 'notifications_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LoginFormData()),
        Provider(create: (context) => AuthService()),
        Provider(create: (context) => DatabaseService()),
      ],
      child: const MyApp(),
    ),
  );
}

class LoginFormData extends ChangeNotifier {
  String username = '';
  String password = '';
  bool rememberMe = false;
  late SharedPreferences _prefs;

  LoginFormData() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    username = _prefs.getString('saved_username') ?? '';
    password = _prefs.getString('saved_password') ?? '';
    rememberMe = _prefs.getBool('remember_me') ?? false;
    notifyListeners();
  }

  Future<void> _saveCredentials() async {
    if (rememberMe) {
      await _prefs.setString('saved_username', username);
      await _prefs.setString('saved_password', password);
    } else {
      await _prefs.remove('saved_username');
      await _prefs.remove('saved_password');
    }
    await _prefs.setBool('remember_me', rememberMe);
  }

  void setUsername(String value) {
    username = value;
    notifyListeners();
  }

  void setPassword(String value) {
    password = value;
    notifyListeners();
  }

  void setRememberMe(bool value) {
    rememberMe = value;
    _saveCredentials();
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StoraNova Login',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE3F2FD), // Soft blue background
        canvasColor: const Color(0xFFE3F2FD),
        cardColor: Colors.white, // White cards for contrast
        dialogBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2), // Darker blue for app bar
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1976D2), // Darker blue for bottom nav
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFFBBDEFB),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          surface: Colors.white,
          background: const Color(0xFFE3F2FD),
        ),
      ),
      home: const SplashToLogin(),
    );
  }
}

class AppUser {
  final String username;
  final String password;
  final String role;

  AppUser({required this.username, required this.password, required this.role});
}

class SplashToLogin extends StatefulWidget {
  const SplashToLogin({super.key});

  @override
  State<SplashToLogin> createState() => _SplashToLoginState();
}

class _SplashToLoginState extends State<SplashToLogin> {
  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Show splash for a few seconds
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Define animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // Full rotation
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
    ));
    
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.elasticOut,
    ));
    
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations in sequence
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    // Start logo animation
    _logoController.forward();
    
    // Start pulsing effect
    _pulseController.repeat(reverse: true);
    
    // Start particle animation immediately for background effect
    _particleController.repeat();
    
    // Start text animation after a short delay
    await Future.delayed(const Duration(milliseconds: 1200));
    _textController.forward();
    
    // Start progress animation
    await Future.delayed(const Duration(milliseconds: 600));
    _progressController.forward();
    
    // Wait for progress to complete and add a brief pause
    await Future.delayed(const Duration(milliseconds: 2800));
    
    // Navigate to login page with simple fade transition
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Simple fade transition - login page stays in place
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1), // Deep blue
              Color(0xFF1565C0), // Darker blue
              Color(0xFF1976D2), // Primary blue
              Color(0xFF1E88E5), // Medium blue
              Color(0xFF42A5F5), // Lighter blue
              Color(0xFF64B5F6), // Even lighter blue
              Color(0xFF90CAF9), // Light blue
            ],
            stops: [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated particles background
            AnimatedBuilder(
              animation: _particleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(_particleAnimation.value),
                  size: Size.infinite,
                );
              },
            ),
            
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo with pulsing effect
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoController, _pulseController]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value * _pulseAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFFF5F5F5),
                                ],
                                stops: [0.7, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF1976D2).withOpacity(0.4),
                                  blurRadius: 50,
                                  offset: const Offset(0, 0),
                                  spreadRadius: 15,
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, -5),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Inner glow effect
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF1976D2).withOpacity(0.15),
                                        const Color(0xFF1976D2).withOpacity(0.05),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.3, 0.7, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                // Main icon with gradient
                                ShaderMask(
                                  shaderCallback: (bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0D47A1),
                                        Color(0xFF1976D2),
                                        Color(0xFF42A5F5),
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: const Icon(
                                    Icons.home_work,
                                    size: 70,
                                    color: Colors.white,
                                  ),
                                ),
                                // Subtle sparkle effect
                                Positioned(
                                  top: 25,
                                  right: 25,
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value * 0.8,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.5),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Animated text
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textOpacityAnimation,
                          child: Column(
                            children: [
                              const Text(
                                'StoraNova',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(3, 3),
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: Colors.blue,
                                      offset: Offset(0, 0),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Store Smarter. Work Faster.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.95),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w300,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Animated progress indicator with glow
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Column(
                        children: [
                          Container(
                            width: 280,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 280 * _progressAnimation.value,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Color(0xFFE3F2FD),
                                        Color(0xFFBBDEFB),
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.8),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF64B5F6).withOpacity(0.6),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                // Progress shimmer effect
                                if (_progressAnimation.value > 0.1)
                                  Positioned(
                                    left: (280 * _progressAnimation.value) - 40,
                                    child: Container(
                                      width: 30,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withOpacity(0.8),
                                            Colors.transparent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          FadeTransition(
                            opacity: _progressAnimation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Loading dots animation
                                ...List.generate(3, (index) {
                                  return AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (context, child) {
                                      final delay = index * 0.2;
                                      final animValue = (_progressAnimation.value - delay).clamp(0.0, 1.0);
                                      final opacity = (math.sin(animValue * math.pi * 4) * 0.5 + 0.5).clamp(0.3, 1.0);
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(opacity),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(opacity * 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }),
                                const SizedBox(width: 15),
                                Text(
                                  'Initializing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 1.2,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Floating dots animation
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FloatingDotsPainter(_particleAnimation.value),
                  size: Size.infinite,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for floating particles
class ParticlePainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles;
  
  ParticlePainter(this.animationValue) : particles = List.generate(50, (index) => Particle());
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    for (var particle in particles) {
      final x = (particle.x * size.width + animationValue * particle.speed * 100) % size.width;
      final y = (particle.y * size.height + animationValue * particle.speed * 50) % size.height;
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint..color = Colors.white.withOpacity(particle.opacity),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  
  Particle()
      : x = (math.Random().nextDouble()),
        y = (math.Random().nextDouble()),
        size = math.Random().nextDouble() * 3 + 1,
        speed = math.Random().nextDouble() * 2 + 0.5,
        opacity = math.Random().nextDouble() * 0.3 + 0.1;
}

// Custom painter for floating dots with enhanced visual effects
class FloatingDotsPainter extends CustomPainter {
  final double animationValue;
  final List<FloatingDot> dots;
  
  FloatingDotsPainter(this.animationValue) : dots = List.generate(30, (index) => FloatingDot());
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var dot in dots) {
      final x = (dot.x * size.width + animationValue * dot.speedX * 200) % size.width;
      final y = (dot.y * size.height + animationValue * dot.speedY * 150) % size.height;
      
      // Create glowing effect
      final glowPaint = Paint()
        ..color = dot.color.withOpacity(dot.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      final dotPaint = Paint()
        ..color = dot.color.withOpacity(dot.opacity)
        ..style = PaintingStyle.fill;
      
      // Draw glow
      canvas.drawCircle(Offset(x, y), dot.size * 2, glowPaint);
      
      // Draw dot
      canvas.drawCircle(Offset(x, y), dot.size, dotPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FloatingDot {
  final double x;
  final double y;
  final double size;
  final double speedX;
  final double speedY;
  final double opacity;
  final Color color;
  
  FloatingDot()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        size = math.Random().nextDouble() * 4 + 2,
        speedX = (math.Random().nextDouble() - 0.5) * 2,
        speedY = (math.Random().nextDouble() - 0.5) * 2,
        opacity = math.Random().nextDouble() * 0.4 + 0.2,
        color = _getRandomColor();
  
  static Color _getRandomColor() {
    final colors = [
      Colors.white,
      const Color(0xFFE3F2FD),
      const Color(0xFFBBDEFB),
      const Color(0xFF90CAF9),
      const Color(0xFF64B5F6),
    ];
    return colors[math.Random().nextInt(colors.length)];
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showRegistration = false;
  final TextEditingController _regUsernameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regConfirmPasswordController = TextEditingController();
  String _selectedRole = 'Customer';

  @override
  void dispose() {
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}").hasMatch(email);
  }

  Future<void> _handleLogin(BuildContext context) async {
    final formData = Provider.of<LoginFormData>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    // Prevent login if username/email or password is empty
    if (formData.username.trim().isEmpty || formData.password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your username/email and password.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // IMPORTANT: Sign out any existing user first to prevent session conflicts
      print("Current user before signOut: ${authService.currentUser?.email}");
      await authService.signOut();
      print("Successfully signed out, current user: ${authService.currentUser?.email}");
      
      // Allow login with username or email
      String loginInput = formData.username.trim();
      String? emailToUse;
      if (isValidEmail(loginInput)) {
        emailToUse = loginInput;
        print("Using email directly: $emailToUse");
      } else {
        // Lookup email by username
        print("Looking up email for username: $loginInput");
        final userDoc = await dbService.getUserByUsername(loginInput);
        if (userDoc == null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username not found.')),
          );
          return;
        }
        emailToUse = userDoc['email'] as String?;
        print("Found email for username: $emailToUse");
        if (emailToUse == null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email not found for this username.')),
          );
          return;
        }
      }

      print("Attempting to sign in with email: $emailToUse");
      final user = await authService.signInWithEmailPassword(
        emailToUse,
        formData.password,
      );

      print("Sign in result: ${user != null ? 'Success (${user.email})' : 'Failed (null user)'}");
      Navigator.of(context).pop();

      if (user != null) {
        print("Processing successful login for user: ${user.email}");
        String? role;
        String username;
        // If login was by username, use it directly
        if (!isValidEmail(formData.username.trim())) {
          username = formData.username.trim();
          print("Using provided username: $username");
          role = await dbService.getUserRole(username);
          print("Role from database for $username: $role");
        } else {
          // If login was by email, need to find username by email
          print("Looking up username by email: ${formData.username.trim()}");
          final usersSnapshot = await dbService.usersCollection.where('email', isEqualTo: formData.username.trim()).get();
          if (usersSnapshot.docs.isNotEmpty) {
            username = usersSnapshot.docs.first.id;
            role = usersSnapshot.docs.first['role'] as String?;
            print("Found username: $username, role: $role");
          } else {
            print("No user found with email: ${formData.username.trim()}");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not found')),
            );
            return;
          }
        }

        if (role == null) {
          print("Role is null for user: $username");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User role not found')),
          );
          return;
        }

        // Check if user is banned
        final userDoc = await dbService.getUserByUsername(username);
        final Map<String, dynamic>? userData = userDoc?.data() as Map<String, dynamic>?;
        final bool isUserBanned = userData != null && userData.containsKey('isBanned') 
            ? userData['isBanned'] == true 
            : false;

        print('Debug: User $username, Role: $role, Banned: $isUserBanned'); // Debug line

        if (isUserBanned) {
          // Redirect banned users to notifications page
          print('Debug: Redirecting banned user to notifications'); // Debug line
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => NotificationsPage(expectedRole: role?.toLowerCase() ?? 'customer')),
          );
          return;
        }

        print('Debug: Navigating to dashboard for role: $role'); // Debug line
        final roleUpper = role.toUpperCase();
        if (roleUpper == 'OWNER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OwnerHomePage()),
          );
        } else if (roleUpper == 'CUSTOMER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustHomePage()),
          );
        } else if (roleUpper == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminHomePage()),
          );
        } else {
          print('Debug: Unknown role: $role');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid user role')),
          );
        }
      } else {
        print("Sign in failed - user is null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username/email or password')),
        );
      }
    } catch (e) {
      print("Exception in login: $e");
      print("Stack trace: ${StackTrace.current}");
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleRegistration(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirmPassword = _regConfirmPasswordController.text;
    final role = _selectedRole;

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }
    
    // Username validation
    if (username.length < 3 || username.length > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be between 3 and 12 characters long.')),
      );
      return;
    }
    
    if (username.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot contain spaces.')),
      );
      return;
    }
    
    // Check for valid username characters (alphanumeric and underscore only)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username can only contain letters, numbers, and underscores.')),
      );
      return;
    }
    
    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Check if username already exists
      final existingUser = await dbService.getUserByUsername(username);
      if (existingUser != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already taken.')),
        );
        return;
      }

      User? user = await authService.registerWithEmailPassword(
        email,
        password,
        role,
      );
      // Save username and role in Firestore (username as doc ID)
      if (user != null) {
        await dbService.createUser(
          username: username,
          email: email,
          role: role,
        );
      }
      Navigator.of(context).pop();
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please log in.')),
        );
        setState(() {
          showRegistration = false;
        });
        _regUsernameController.clear();
        _regEmailController.clear();
        _regPasswordController.clear();
        _regConfirmPasswordController.clear();
        _selectedRole = 'Customer';
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://res.cloudinary.com/dxeejx1hq/image/upload/v1752252317/grf8snwyr5evx3v6vgfs.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: showRegistration
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 50.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: _buildRegistrationForm(context),
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(maxWidth: 350),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: _buildLoginForm(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              'https://res.cloudinary.com/dxeejx1hq/image/upload/v1752252900/rvmpbicbuori5bwtajw1.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'StoraNova',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Consumer<LoginFormData>(
          builder: (context, formData, child) => SizedBox(
            width: 300,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Email or Username',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => formData.setUsername(value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Consumer<LoginFormData>(
          builder: (context, formData, child) => SizedBox(
            width: 300,
            child: TextField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => formData.setPassword(value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () {
              // Handle forgot password logic here
            },
            child: const Text(
              'FORGOT PASSWORD?',
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _handleLogin(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            textStyle: const TextStyle(fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
          child: const Text('LOG IN', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                showRegistration = true;
              });
            },
            child: const Text(
              'NEW USER REGISTRATION',
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 10),

      ],
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              'https://res.cloudinary.com/dxeejx1hq/image/upload/v1752252900/rvmpbicbuori5bwtajw1.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Register New Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _regUsernameController,
            decoration: InputDecoration(
              hintText: 'Username',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
          child: Text(
            '⚠️ Note: Username cannot be changed after registration. Choose wisely!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _regEmailController,
            decoration: InputDecoration(
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Role Dropdown
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              hintText: 'Role',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'Customer', child: Text('Customer')),
              DropdownMenuItem(value: 'Owner', child: Text('Owner')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRole = value ?? 'Customer';
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _regPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _regConfirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _handleRegistration(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
          child: const Text('REGISTER', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            setState(() {
              showRegistration = false;
            });
          },
          child: const Text(
            'Back to Login',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}