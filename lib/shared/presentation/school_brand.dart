import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const schoolLogoAsset = 'assets/images/logo/school logo.jpg';

class SchoolBrandLogo extends StatelessWidget {
  const SchoolBrandLogo({this.size = 52, this.showShadow = true, super.key});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          schoolLogoAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SchoolBrandLogo(size: 88),
              SizedBox(height: 28),
              Text(
                'TWCES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 20),
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
