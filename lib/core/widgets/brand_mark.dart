import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AssetPaths.appMark,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Tafseer Audio',
    );
  }
}
