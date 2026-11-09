import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _requested = false;
  bool _loading = false;
  bool _obscure = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    final initialToken = widget.initialToken?.trim();
    if (initialToken != null && initialToken.isNotEmpty) {
      _token.text = initialToken;
      _requested = true;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_email.text.contains('@')) {
      setState(() => _message = 'Ingresa un correo electrónico válido.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text);
      _token.text = result.developmentToken ?? '';
      if (mounted) {
        setState(() {
          _requested = true;
          _message = result.developmentToken == null
              ? result.message
              : '${result.message} El token local se completó automáticamente.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_token.text.trim().isEmpty) {
      setState(() => _message = 'Ingresa el token de recuperación.');
      return;
    }
    if (_password.text.length < 8 ||
        !_password.text.contains(RegExp('[A-Z]')) ||
        !_password.text.contains(RegExp('[a-z]')) ||
        !_password.text.contains(RegExp('[0-9]')) ||
        !_password.text.contains(RegExp(r'[^A-Za-z0-9]'))) {
      setState(
        () => _message =
            'Usa al menos 8 caracteres, mayúscula, minúscula, número y símbolo.',
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: _token.text, newPassword: _password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
          ),
        );
        context.go(AppRoutes.login);
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= AppDimensions.expandedBreakpoint;
          final form = _PasswordResetForm(
            requested: _requested,
            loading: _loading,
            obscure: _obscure,
            message: _message,
            email: _email,
            token: _token,
            password: _password,
            confirmation: _confirmation,
            onRequest: _request,
            onConfirm: _confirm,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          );
          if (isWide) {
            return Row(
              children: [
                const Expanded(child: _PasswordResetBrandPanel()),
                Expanded(child: _PasswordResetFormPanel(child: form)),
              ],
            );
          }
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: form,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PasswordResetFormPanel extends StatelessWidget {
  const _PasswordResetFormPanel({required this.child});

  final Widget child;

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
            constraints: const BoxConstraints(maxWidth: AppDimensions.formMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PasswordResetForm extends StatelessWidget {
  const _PasswordResetForm({
    required this.requested,
    required this.loading,
    required this.obscure,
    required this.email,
    required this.token,
    required this.password,
    required this.confirmation,
    required this.onRequest,
    required this.onConfirm,
    required this.onToggleObscure,
    this.message,
  });

  final bool requested;
  final bool loading;
  final bool obscure;
  final String? message;
  final TextEditingController email;
  final TextEditingController token;
  final TextEditingController password;
  final TextEditingController confirmation;
  final VoidCallback onRequest;
  final VoidCallback onConfirm;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final showInlineLogo =
        MediaQuery.sizeOf(context).width < AppDimensions.expandedBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showInlineLogo) ...[
          const Center(child: AppLogo(height: 48)),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(
          requested ? 'Crea una nueva contraseña' : 'Recupera el acceso',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          requested
              ? 'Ingresa el token recibido y define tu nueva contraseña.'
              : 'Te enviaremos instrucciones si el correo está registrado.',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!requested) ...[
          AppTextField(
            controller: email,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onRequest(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: loading ? null : onRequest,
            child: Text(loading ? 'Enviando...' : 'Enviar instrucciones'),
          ),
        ] else ...[
          AppTextField(
            controller: token,
            label: 'Token de recuperación',
            prefixIcon: Icons.key_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: password,
            label: 'Nueva contraseña',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: obscure,
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: confirmation,
            label: 'Confirmar contraseña',
            prefixIcon: Icons.lock_reset_outlined,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onConfirm(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: loading ? null : onConfirm,
            child: Text(loading ? 'Actualizando...' : 'Cambiar contraseña'),
          ),
        ],
        if (message case final value?) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(value),
        ],
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ),
      ],
    );
  }
}

class _PasswordResetBrandPanel extends StatelessWidget {
  const _PasswordResetBrandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceDark,
      child: Stack(
        children: [
          const Positioned.fill(child: _PasswordResetPattern()),
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
                        text: 'Vuelve a entrar\na tu cuenta ',
                        children: [
                          const TextSpan(
                            text: 'Doc IA.',
                            style: TextStyle(color: AppColors.tealLight),
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
                  Container(
                    width: 365,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.14),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      'Actualiza tu contraseña y continúa con tus citas, pagos y seguimiento clínico.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.white70,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordResetPattern extends StatelessWidget {
  const _PasswordResetPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PasswordResetPatternPainter());
  }
}

class _PasswordResetPatternPainter extends CustomPainter {
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
