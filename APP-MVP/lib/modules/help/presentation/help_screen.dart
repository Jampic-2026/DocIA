import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayuda'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Preguntas'),
              Tab(text: 'Demo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FaqView(),
            _DemoView(),
          ],
        ),
      ),
    );
  }
}

class _FaqView extends StatelessWidget {
  const _FaqView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        _FaqTile(
          question: '¿Cómo funcionan las monedas Doc IA?',
          answer:
              'Tienes 15 monedas gratuitas cada semana. El chat usa 1 moneda por mensaje y las llamadas de voz usan 1 moneda por minuto iniciado.',
        ),
        _FaqTile(
          question: '¿Qué pasa si se acaban mis monedas en una llamada?',
          answer:
              'La app te avisa antes de agotar saldo y la llamada se finaliza al llegar al límite disponible.',
        ),
        _FaqTile(
          question: '¿El asistente reemplaza una consulta médica?',
          answer:
              'No. El asistente entrega orientación preliminar. Si hay síntomas graves, busca atención médica o emergencia.',
        ),
        _FaqTile(
          question: '¿Cómo compro monedas?',
          answer:
              'En Mi cuenta entra a Monedas Doc IA, elige un paquete y paga con tarjeta cuando Stripe esté configurado.',
        ),
        _FaqTile(
          question: '¿Dónde veo mis pagos?',
          answer:
              'En Mi cuenta, abre Pagos y órdenes de pago para revisar órdenes, historial y estados.',
        ),
        _FaqTile(
          question: '¿Cómo manejo mis consentimientos?',
          answer:
              'En Mi cuenta entra a Privacidad y consentimientos. Algunos servicios, como IA o telemedicina, requieren aceptación previa.',
        ),
      ],
    );
  }
}

class _DemoView extends StatelessWidget {
  const _DemoView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        _DemoStep(
          icon: Icons.home_outlined,
          title: 'Inicio',
          description:
              'Revisa accesos rápidos, próximos eventos y el resumen principal de tu atención.',
        ),
        _DemoStep(
          icon: Icons.calendar_month_outlined,
          title: 'Citas',
          description:
              'Agenda consultas, revisa detalles y entra a telemedicina cuando corresponda.',
        ),
        _DemoStep(
          icon: Icons.smart_toy_outlined,
          title: 'Asistente',
          description:
              'Envía mensajes cortos, usa tus monedas semanales y accede a llamadas de voz guiadas.',
        ),
        _DemoStep(
          icon: Icons.toll_outlined,
          title: 'Monedas',
          description:
              'Consulta saldo, historial y compra paquetes. Las monedas gratuitas se consumen primero.',
        ),
        _DemoStep(
          icon: Icons.person_outline_rounded,
          title: 'Cuenta',
          description:
              'Actualiza datos personales, revisa consentimientos, pagos, beneficios y ayuda.',
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(answer),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoStep extends StatelessWidget {
  const _DemoStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.teal.withValues(alpha: 0.14),
              child: Icon(icon, color: AppColors.teal),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
