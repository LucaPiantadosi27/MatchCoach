import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore di accesso: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.4,
                colors: [
                  Color(0xFF1A2F1A),
                  Color(0xFF0D1117),
                  Color(0xFF0D1117),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // ── Green glow top
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x3040C057), Color(0x0040C057)],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          // ── Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Logo
                          _buildLogo(),
                          const SizedBox(height: 44),

                          // ── Email
                          _buildLabel('Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'la-tua@email.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci la tua email';
                              }
                              if (!value.contains('@')) {
                                return 'Inserisci un\'email valida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Password
                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Inserisci la password';
                              }
                              if (value.length < 6) {
                                return 'Almeno 6 caratteri';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // ── Login button
                          _buildPrimaryButton(),
                          const SizedBox(height: 24),

                          // ── Register link
                          _buildRegisterLink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Icon with glow
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A2F1A),
            border: Border.all(color: AppTheme.accentGreenDim, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6040C057),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            size: 44,
            color: AppTheme.accentGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'MatchCoach-AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Accedi al tuo account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
              ),
        color: _isLoading ? AppTheme.sidebarSectionColor : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _isLoading
            ? null
            : const [
                BoxShadow(
                  color: Color(0x5540C057),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _signIn,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : const Text(
                    'Accedi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Non hai un account?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () => context.go('/register'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Registrati',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
