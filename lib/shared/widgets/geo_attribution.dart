import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GeoAttribution extends StatelessWidget {
  const GeoAttribution({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    children: [
      TextButton(
        onPressed: () => launchUrl(Uri.parse('https://www.geoapify.com/')),
        child: const Text(
          'Powered by Geoapify',
          style: TextStyle(fontSize: 11),
        ),
      ),
      TextButton(
        onPressed: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 11),
        ),
      ),
    ],
  );
}

