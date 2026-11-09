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
import '../domain/auth_repository.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _registrationFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _secondLastName = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _documentNumber = TextEditingController();
  final _municipality = TextEditingController();
  final _zone = TextEditingController();
  final _address = TextEditingController();
  final _guardianEmail = TextEditingController();
  final _guardianRelationship = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _documentType;
  String? _message;
  String? _error;
  bool _isLoading = false;
  bool _requestSent = false;
  bool _registrationComplete = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptRequiredConsents = false;

  bool get _hasToken => _token.text.trim().isNotEmpty;

  bool get _isMinor {
    final birthDate = _selectedBirthDate;
    if (birthDate == null) return false;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age < 18;
  }

  @override
  void initState() {
    super.initState();
    _token.text = widget.initialToken?.trim() ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _email,
      _token,
      _firstName,
      _lastName,
      _secondLastName,
      _phone,
      _birthDate,
      _documentNumber,
      _municipality,
      _zone,
      _address,
      _guardianEmail,
      _guardianRelationship,
      _password,
      _passwordConfirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _requestRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .requestRegistration(_email.text);
      if (!mounted) return;
      setState(() {
        _requestSent = true;
        _message = response.message;
        if (response.developmentToken != null) {
          _token.text = response.developmentToken!;
        }
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar el registro.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBirthDate() async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) => Theme(
        data: theme.copyWith(
          datePickerTheme: theme.datePickerTheme.copyWith(
            cancelButtonStyle: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              minimumSize: const Size(104, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              side: BorderSide(color: scheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            confirmButtonStyle: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(104, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null) return;
    setState(() {
      _selectedBirthDate = selected;
      _birthDate.text =
          '${selected.day.toString().padLeft(2, '0')}/'
          '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    });
  }

  Future<void> _completeRegistration() async {
    FocusScope.of(context).unfocus();
    if (!_acceptRequiredConsents) return;
    if (!_registrationFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeRegistration(
        RegistrationData(
          token: _token.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          secondLastName: _secondLastName.text,
          phone: _phone.text,
          birthDate: _selectedBirthDate!,
          documentType: _documentType,
          documentNumber: _documentNumber.text,
          municipality: _municipality.text,
          zone: _zone.text,
          addressLine: _address.text,
          acceptRequiredConsents: _acceptRequiredConsents,
          guardianEmail: _isMinor ? _guardianEmail.text : null,
          guardianRelationship: _isMinor
              ? _guardianRelationship.text
              : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _registrationComplete = true;
        _message = 'Tu cuenta de paciente fue creada correctamente.';
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo completar el registro.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= AppDimensions.expandedBreakpoint;
          final form = _registrationComplete
              ? _buildSuccess(context)
              : _hasToken
              ? _buildRegistrationForm(context)
              : _buildEmailStep(context);
          return Stack(
            children: [
              if (isWide)
                Row(
                  children: [
                    const Expanded(child: _RegistrationBrandPanel()),
                    Expanded(child: _RegistrationFormPanel(child: form)),
                  ],
                )
              else
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: form,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String title, String subtitle) {
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
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            context,
            'Crea tu cuenta',
            'El registro público crea una cuenta de paciente. Para ejercer como profesional de salud deberás postularte y completar la verificación correspondiente.',
          ),
          AppTextField(
            controller: _email,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _StatusBanner(message: _message!, isError: false),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _StatusBanner(message: _error!, isError: true),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _isLoading ? null : _requestRegistration,
            child: _isLoading
                ? const _ButtonProgress()
                : Text(_requestSent ? 'Reenviar enlace' : 'Continuar'),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    return Form(
      key: _registrationFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            context,
            'Completa tus datos',
            'Estos datos conformarán tu perfil personal y tu perfil de paciente.',
          ),
          _sectionTitle(context, 'Datos personales'),
          _responsiveFields([
            AppTextField(
              controller: _firstName,
              label: 'Nombres',
              validator: _requiredValidator,
            ),
            AppTextField(
              controller: _lastName,
              label: 'Primer apellido',
              validator: _requiredValidator,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _responsiveFields([
            AppTextField(
              controller: _secondLastName,
              label: 'Segundo apellido (opcional)',
            ),
            AppTextField(
              controller: _birthDate,
              label: 'Fecha de nacimiento',
              hint: 'DD/MM/AAAA',
              prefixIcon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: _selectBirthDate,
              validator: (_) => _selectedBirthDate == null
                  ? 'Selecciona tu fecha de nacimiento'
                  : null,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _phone,
            label: 'Teléfono (opcional)',
            hint: '+591 70000000',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              final phone = value?.trim() ?? '';
              if (phone.isEmpty) return null;
              return RegExp(r'^\+?[0-9][0-9\s-]{6,38}$').hasMatch(phone)
                  ? null
                  : 'Ingresa un teléfono válido';
            },
          ),
          if (_isMinor) ...[
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle(context, 'Tutor responsable'),
            Text(
              'Las personas menores de 18 años deben vincular una cuenta adulta activa.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _responsiveFields([
              AppTextField(
                controller: _guardianEmail,
                label: 'Correo del tutor',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              AppTextField(
                controller: _guardianRelationship,
                label: 'Parentesco o relación',
                hint: 'Madre, padre, tutor legal',
                validator: _requiredValidator,
              ),
            ]),
          ],
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle(context, 'Documento y domicilio'),
          _responsiveFields([
            DropdownButtonFormField<String>(
              initialValue: _documentType,
              decoration: const InputDecoration(labelText: 'Tipo de documento'),
              items: const [
                DropdownMenuItem(value: 'CI', child: Text('Cédula de identidad')),
                DropdownMenuItem(value: 'PASSPORT', child: Text('Pasaporte')),
                DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _documentType = value),
            ),
            AppTextField(
              controller: _documentNumber,
              label: 'Número de documento (opcional)',
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _responsiveFields([
            AppTextField(
              controller: _municipality,
              label: 'Municipio (opcional)',
            ),
            AppTextField(controller: _zone, label: 'Zona (opcional)'),
          ]),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _address,
            label: 'Dirección (opcional)',
          ),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle(context, 'Seguridad'),
          _responsiveFields([
            AppTextField(
              controller: _password,
              label: 'Contraseña',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) => (value?.length ?? 0) < 10
                  ? 'Utiliza al menos 10 caracteres'
                  : null,
            ),
            AppTextField(
              controller: _passwordConfirmation,
              label: 'Confirma la contraseña',
              obscureText: _obscureConfirmation,
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                icon: Icon(
                  _obscureConfirmation
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) => value != _password.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          CheckboxListTile(
            value: _acceptRequiredConsents,
            onChanged: _isLoading
                ? null
                : (value) => setState(
                    () => _acceptRequiredConsents = value ?? false,
                  ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Acepto los Términos y condiciones y la Política de privacidad',
            ),
            subtitle: const Text(
              'La aceptación es obligatoria para crear una cuenta y no puede retirarse mientras la cuenta permanezca activa.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _StatusBanner(message: _error!, isError: true),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _isLoading || !_acceptRequiredConsents
                ? null
                : _completeRegistration,
            child: _isLoading
                ? const _ButtonProgress()
                : const Text('Crear mi cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      children: [
        const AppLogo(height: 52),
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.secondary,
          size: 72,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Cuenta creada',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_message!, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Iniciar sesión'),
        ),
      ],
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index < fields.length - 1)
                  const SizedBox(height: AppSpacing.lg),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Expanded(child: fields[index]),
              if (index < fields.length - 1)
                const SizedBox(width: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null;

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Correo no válido';
  }
}

class _RegistrationFormPanel extends StatelessWidget {
  const _RegistrationFormPanel({required this.child});

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
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RegistrationBrandPanel extends StatelessWidget {
  const _RegistrationBrandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceDark,
      child: Stack(
        children: [
          const Positioned.fill(child: _RegistrationPattern()),
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
                        text: 'Tu salud digital,\nlista desde el ',
                        children: [
                          const TextSpan(
                            text: 'primer\nregistro.',
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
                      'Crea una cuenta de paciente para agendar, usar el asistente y gestionar tu información clínica.',
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

class _RegistrationPattern extends StatelessWidget {
  const _RegistrationPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RegistrationPatternPainter());
  }
}

class _RegistrationPatternPainter extends CustomPainter {
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppColors.danger
        : Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.mark_email_read_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation(AppColors.white),
      ),
    );
  }
}
