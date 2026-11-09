import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'config/build_config.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  BuildConfig.validate();
  if (BuildConfig.stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = BuildConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
  }
  await initializeDateFormatting('es_BO', null);

  runApp(
    const ProviderScope(
      child: DocIaApp(),
    ),
  );
}
