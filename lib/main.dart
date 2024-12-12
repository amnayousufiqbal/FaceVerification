import 'package:flutter/material.dart';
import 'upload_image_screen.dart';

void main() {
  runApp(const FaceMatchApp());
}

class FaceMatchApp extends StatelessWidget {
  const FaceMatchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Matching App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UploadImageScreen(),
    );
  }
}
