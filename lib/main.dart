import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'owner_dashboard.dart';
import 'cust_dashboard.dart';


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LoginFormData(),
      child: const MyApp(),
    ),
  );
}

class LoginFormData extends ChangeNotifier {
  String username = '';
  String password = '';
  bool rememberMe = false;


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
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoraNova Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

class User {
  final String username;
  final String password;
  final String role;

  User({required this.username, required this.password, required this.role});
}

// Mock user data
final List<User> mockUsers = [
  User(username: 'admin', password: 'admin123', role: 'admin'),
  User(username: 'user', password: 'user123', role: 'user'),
];

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _handleLogin(BuildContext context) {
    final formData = Provider.of<LoginFormData>(context, listen: false);
    final user = mockUsers.firstWhere(
      (u) => u.username == formData.username && u.password == formData.password,
      orElse: () => User(username: '', password: '', role: ''),
    );

    if (user.role == 'admin') {
      // Navigate or show admin UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome, Admin!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OwnerHomePage()),
      ); // Navigate to admin page
    } else if (user.role == 'user') {
      // Navigate or show user UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome, User!')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CustHomePage()),
      ); // Navigate to user page
    } else {
      // Invalid credentials
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid username or password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay with Login Form
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
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
                    // Username Input
                    Consumer<LoginFormData>(
                      builder: (context, formData, child) => SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'USERNAME',
                            prefixIcon: const Icon(Icons.person_outline),
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
                    // Password Input
                    Consumer<LoginFormData>(
                      builder: (context, formData, child) => SizedBox(
                        width: 300,
                        child: TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'PASSWORD',
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
                    // Remember Me Checkbox
                    Consumer<LoginFormData>(
                      builder: (context, formData, child) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: formData.rememberMe,
                            onChanged: (value) => formData.setRememberMe(value ?? false),
                          ),
                          const Text('Keep Me Logged In'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Login Button
                    ElevatedButton(
                      onPressed: () => _handleLogin(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                      ),
                      child: const Text('LOG IN', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    // Forgot Password & New User Registration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Handle forgot password logic here
                          },
                          child: const Text(
                            'FORGOT PASSWORD?',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const Text(
                          '|',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () {
                            // Handle new user registration logic here
                          },
                          child: const Text(
                            'NEW USER REGISTRATION',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Or Log In Using
                    const Text(
                      'Or Log In Using:',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    // Social Login Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            // Handle Google login logic here
                          },
                          icon: Image.network(
                              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                              width: 24,
                              height: 24),
                        ),
                        IconButton(
                          onPressed: () {
                            // Handle Apple login logic here
                          },
                          icon: Image.network(
                              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                              width: 24,
                              height: 24),
                        ),
                        IconButton(
                          onPressed: () {
                            // Handle Facebook login logic here
                          },
                          icon: Image.network(
                              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                              width: 24,
                              height: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}