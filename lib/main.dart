import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_raise_demo/views/hand_raise_screen.dart'; 

// 利用可能なカメラのリストを格納するためのグローバル変数を宣言
late List<CameraDescription> cameras;

Future<void> main() async {
  // Flutterエンジンの初期化を確実に行う（カメラパッケージを使用する前に必須）
  WidgetsFlutterBinding.ensureInitialized();
  
  // デバイス上で利用可能なすべてのカメラを取得
  cameras = await availableCameras();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '舉手辨識 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      // ホーム画面を独自に作成したHandRaiseDetectionScreenに置き換え、カメラリストを渡す
      home: HandRaiseDetectionScreen(cameras: cameras), 
    );
  }
}