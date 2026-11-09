import 'package:flutter/material.dart';

class MeasurementChart extends StatelessWidget {
  const MeasurementChart({
    super.key,
    required this.points,
    required this.metric,
  });
  final List<Map<String, dynamic>> points;
  final String metric;
  @override
  Widget build(BuildContext context) {
    final values = points
        .where((point) => point[metric] is num && point['isValid'] != false)
        .toList();
    if (values.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Se requieren dos mediciones válidas para dibujar una evolución. Puedes consultar cada medición.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Semantics(
          label:
              'Evolución temporal. Los valores y fechas se detallan debajo del gráfico.',
          child: CustomPaint(
            painter: _MeasurementPainter(
              values,
              metric,
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasurementPainter extends CustomPainter {
  _MeasurementPainter(this.points, this.metric, this.color);
  final List<Map<String, dynamic>> points;
  final String metric;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final times = points
        .map(
          (point) => DateTime.parse(
            point['recordedAt'] as String,
          ).millisecondsSinceEpoch.toDouble(),
        )
        .toList();
    final values = points
        .map((point) => (point[metric] as num).toDouble())
        .toList();
    final minimum = values.reduce((a, b) => a < b ? a : b),
        maximum = values.reduce((a, b) => a > b ? a : b);
    final span = maximum - minimum, period = times.last - times.first;
    final offsets = [
      for (var i = 0; i < values.length; i++)
        Offset(
          8 +
              (period == 0
                      ? i / (values.length - 1)
                      : (times[i] - times.first) / period) *
                  (size.width - 16),
          8 +
              (span == 0 ? 0.5 : (maximum - values[i]) / span) *
                  (size.height - 16),
        ),
    ];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (final point in offsets) {
      canvas.drawCircle(point, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter old) =>
      old.points != points || old.metric != metric || old.color != color;
}
