// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'options_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! Redirecting...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const OptionsPage(),
            ),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4E342E), Color(0xFF3E2723)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                'assets/images/leco_logo.webp',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildForm(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                             Image.asset('assets/images/leco_logo.webp',
                   width: 60, height: 60, fit: BoxFit.contain),
               const SizedBox(height: 16),
              Text(
                'Docket Tracker',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
                             const SizedBox(height: 8),
               Text(
                 'Log in to continue',
                 style: Theme.of(context)
                     .textTheme
                     .bodyMedium
                     ?.copyWith(color: Colors.grey[600]),
               ),
               const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) =>
                    value != 'paliyagoda@leco.com' ? 'Invalid Email' : null,
              ),
                             const SizedBox(height: 12),
               TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) =>
                    value != '123456' ? 'Invalid Password' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
