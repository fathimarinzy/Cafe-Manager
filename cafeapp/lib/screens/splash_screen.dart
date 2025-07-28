import 'package:flutter/material.dart';
// import '../utils/app_localization.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or name
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: 'SIMS ',
                    style: TextStyle(
                      color: Colors.blue[900],
                    ),
                  ),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
             const SizedBox(height: 10),
            // Subtitle - Cafe Management
            Text(
              'Cafe Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
            // const SizedBox(height: 20),
            // // Loading indicator
            // CircularProgressIndicator(
            //   color: Colors.blue[900],
            // ),
            // const SizedBox(height: 20),
            //  Text(
            //   'Please wait...'.tr(),
            //   style: TextStyle(
            //     fontSize: 16,
            //     color: Colors.grey,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}