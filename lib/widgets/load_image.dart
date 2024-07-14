import 'package:flutter/material.dart';

class LoadAssetImage extends StatelessWidget {
  
  const LoadAssetImage(this.image, {
    super.key,
    this.width,
    this.height, 
    this.cacheWidth,
    this.cacheHeight,
    this.fit,
    this.color
  });

  final String image;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit? fit;
  final Color? color;
  
  @override
  Widget build(BuildContext context) {

    return Image.asset(

      getImgPath(image),
      height: height,
      width: width,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      fit: fit,
      color: color,
      excludeFromSemantics: true,
    );
  }

  static String getImgPath(String name) {
    return 'assets/images/$name';
  }


}






