import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import '../../../core/routing/app_routes.dart';

/// Pantalla común de inicio de sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    // El router redirige automáticamente al home del rol al autenticarse.
    await ref
        .read(authControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppDimensions.expandedBreakpoint;
          return Stack(
            children: [
              if (isWide)
                Row(
                  children: [
                    const Expanded(child: _LoginBrandPanel()),
                    Expanded(
                      child: _LoginFormPanel(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscure: _obscure,
                        auth: auth,
                        onSubmit: _submit,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ],
                )
              else
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: _LoginForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      obscure: _obscure,
                      auth: auth,
                      onSubmit: _submit,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      showLogo: true,
                    ),
                  ),
                ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: IconButton(
                  tooltip: 'Cambiar tema',
                  style: IconButton.styleFrom(
                    backgroundColor: isWide
                        ? scheme.surface.withValues(alpha: 0.86)
                        : null,
                  ),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                  onPressed: () =>
                      ref
                          .read(themeModeProvider.notifier)
                          .toggleFromBrightness(Theme.of(context).brightness),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceDark,
      child: Stack(
        children: [
          const Positioned.fill(child: _LoginPattern()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(height: 48, onDark: true),
                  const SizedBox(height: 48),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text.rich(
                      TextSpan(
                        text: 'La salud del futuro,\nasistida por ',
                        children: [
                          TextSpan(
                            text: 'Inteligencia\nArtificial.',
                            style: const TextStyle(color: AppColors.tealLight),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.14,
                          ),
                    ),
                  ),
                  const Spacer(),
                  const _TrustCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.auth,
    required this.onSubmit,
    required this.onToggleObscure,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final AuthState auth;
  final VoidCallback onSubmit;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 56,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.formMaxWidth,
            ),
            child: _LoginForm(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              obscure: obscure,
              auth: auth,
              onSubmit: onSubmit,
              onToggleObscure: onToggleObscure,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.auth,
    required this.onSubmit,
    required this.onToggleObscure,
    this.showLogo = false,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final AuthState auth;
  final VoidCallback onSubmit;
  final VoidCallback onToggleObscure;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo) ...[
            Center(child: AppLogo(height: 52)),
            const SizedBox(height: AppSpacing.xxl),
          ],
          Text(
            'Bienvenido de nuevo',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicia sesión para acceder a tu cuenta',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: emailController,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@')) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: passwordController,
            label: 'Contraseña',
            hint: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: onToggleObscure,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.passwordReset),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ErrorBanner(message: auth.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: auth.isLoading ? null : onSubmit,
            child: auth.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(AppColors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Iniciar sesión'),
                      SizedBox(width: AppSpacing.sm),
                      Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿No tienes cuenta?'),
              TextButton(
                onPressed: () => context.push(AppRoutes.registration),
                child: const Text('Regístrate'),
              ),
            ],
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push(AppRoutes.registration),
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('¿Eres profesional de salud?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 365,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atención médica conectada, segura y humana',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Accede a orientación, citas, telemedicina y seguimiento clínico desde un solo lugar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white70,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginPattern extends StatelessWidget {
  const _LoginPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LoginPatternPainter());
  }
}

class _LoginPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.white.withValues(alpha: 0.055);
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
