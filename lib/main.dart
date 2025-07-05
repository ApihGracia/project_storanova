import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        primarySwatch: Colors.blue,
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
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Delay for 3 seconds before navigating to LoginScreen
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Text(
          'Welcome to StoraNova!',
          style: TextStyle(fontSize: 30, color: Colors.white),
        ),
      ),
    );
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
            MaterialPageRoute(builder: (context) => NotificationsPage()),
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
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
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
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
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
        const Text(
          'Or Log In Using:',
          style: TextStyle(fontSize: 14, color: Colors.black),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                // Handle Google login logic here
              },
              icon: Image.asset(
                  'assets/images/logo_google.jpg',
                  width: 24,
                  height: 24),
            ),
            IconButton(
              onPressed: () {
                // Handle Apple login logic here
              },
              icon: Image.asset(
                  'assets/images/logo_apple.jpg',
                  width: 24,
                  height: 24),
            ),
            IconButton(
              onPressed: () {
                // Handle Facebook login logic here
              },
              icon: Image.asset(
                  'assets/images/logo_facebook.jpg',
                  width: 24,
                  height: 24),
            ),
          ],
        ),
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
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
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

// Unified StoraNovaNavBar for both customer and owner, accessible from all pages
class StoraNovaNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const StoraNovaNavBar({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    const activeColor = Colors.blue;
    const inactiveColor = Colors.black;
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFB4D4FF),
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: activeColor,
      unselectedItemColor: inactiveColor,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      onTap: onTap,
      items: [
        _buildNavBarItem(Icons.home, 'Home', 0),
        _buildNavBarItem(Icons.favorite_border, 'Wishlist', 1),
        _buildNavBarItem(Icons.notifications_none, 'Notification', 2),
        _buildNavBarItem(Icons.person_outline, 'Profile', 3),
      ],
    );
  }

  BottomNavigationBarItem _buildNavBarItem(IconData icon, String label, int index) {
    final bool isActive = currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        decoration: isActive
            ? BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                shape: BoxShape.circle,
              )
            : null,
        padding: const EdgeInsets.all(8),
        child: Icon(icon),
      ),
      label: label,
    );
  }
}