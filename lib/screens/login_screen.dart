import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_lockup.dart';
import 'map_screen.dart';
import 'admin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _openMap() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const MapScreen()),
  );

  void _signIn() {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password.')),
      );
      return;
    }
    _openMap();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 40 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - (wide ? 80 : 48)).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: wide
                      ? IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(child: _welcomePanel()),
                              const SizedBox(width: 64),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: _form(false),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _form(true),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _welcomePanel({bool compact = false}) => Container(
    height: compact ? 240 : null,
    constraints: compact ? null : const BoxConstraints(minHeight: 650),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(compact ? 24 : 32),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(compact ? 24 : 32),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/branding/campus-welcome.jpg',
            fit: BoxFit.cover,
            alignment: compact
                ? const Alignment(-.4, .2)
                : const Alignment(-.55, 0),
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .28, .52, 1],
                colors: [
                  AppColors.primary.withValues(alpha: .72),
                  AppColors.primary.withValues(alpha: .08),
                  const Color(0xFF27151D).withValues(alpha: .24),
                  const Color(0xFF490A18).withValues(alpha: .97),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(compact ? 24 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandLockup(
                inverse: true,
                compact: compact,
                subtitle: 'YOUR CAMPUS COMPANION',
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(
                'Your campus.\nA little closer.',
                style:
                    (compact
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.displaySmall)
                        ?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
              ),
              if (!compact) ...[
                const SizedBox(height: 16),
                Text(
                  'Find the right building, discover a new corner, '
                  'and feel at home at Holy Angel University.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .9),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Holy Angel University · Angeles City',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _form(bool mobile) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mobile) ...[
          _welcomePanel(compact: true),
          const SizedBox(height: 32),
        ] else ...[
          Text(
            'WELCOME TO LIGHAU',
            style: text.labelSmall?.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Find your way\naround HAU.',
          style: mobile ? text.headlineLarge : text.displaySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Buildings, offices, and campus essentials.\nAll in one place.',
          style: text.bodyMedium?.copyWith(color: AppColors.border),
        ),
        const SizedBox(height: 32),
        Text('Email or username', style: text.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameController,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Enter your email or username',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 20),
        Text('Password', style: text.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _signIn,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Sign In'),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('or explore freely', style: text.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _openMap,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, size: 18),
                SizedBox(width: 10),
                Flexible(child: Text('Continue as Guest')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            ),
            child: const Text('Admin Login'),
          ),
        ),
        if (mobile) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Holy Angel University · Angeles City',
              style: text.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}
