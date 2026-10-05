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

  Widget _welcomePanel() => Container(
    constraints: const BoxConstraints(minHeight: 650),
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLockup(inverse: true, subtitle: 'YOUR CAMPUS COMPANION'),
        const SizedBox(height: 64),
        Text(
          'Your campus.\nA little closer.',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Find the right building, discover a new corner,\nand feel at home at Holy Angel University.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 32),
        const Expanded(
          child: SizedBox(
            width: double.infinity,
            child: CustomPaint(painter: _CampusArtwork()),
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
            Text(
              'Holy Angel University · Angeles City',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
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
          const BrandLockup(subtitle: 'YOUR CAMPUS COMPANION'),
          const SizedBox(height: 40),
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

class _CampusArtwork extends CustomPainter {
  const _CampusArtwork();
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (final r in [
      const Rect.fromLTWH(.04, .14, .23, .34),
      const Rect.fromLTWH(.38, .02, .25, .25),
      const Rect.fromLTWH(.74, .2, .24, .42),
      const Rect.fromLTWH(.22, .68, .32, .3),
      const Rect.fromLTWH(.66, .8, .19, .2),
    ]) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          r.left * size.width,
          r.top * size.height,
          r.width * size.width,
          r.height * size.height,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, outline);
    }
    final path = Path()
      ..moveTo(size.width * .14, size.height * .62)
      ..lineTo(size.width * .34, size.height * .62)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .62,
        size.width * .5,
        size.height * .46,
      )
      ..lineTo(size.width * .5, size.height * .4)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .34,
        size.width * .57,
        size.height * .34,
      )
      ..lineTo(size.width * .67, size.height * .34);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * .14, size.height * .62),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * .67, size.height * .34),
      12,
      Paint()..color = AppColors.secondary.withValues(alpha: .2),
    );
    canvas.drawCircle(
      Offset(size.width * .67, size.height * .34),
      5,
      Paint()..color = AppColors.secondary,
    );
  }

  @override
  bool shouldRepaint(_CampusArtwork oldDelegate) => false;
}
