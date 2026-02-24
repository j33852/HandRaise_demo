import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_raise_demo/viewmodels/hand_raise_view_model.dart';

class HandRaiseDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HandRaiseDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HandRaiseDetectionScreen> createState() => _HandRaiseDetectionScreenState();
}

class _HandRaiseDetectionScreenState extends State<HandRaiseDetectionScreen> {
  // ViewModelのインスタンスを保持する変数
  late final HandRaiseViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    
    _viewModel = HandRaiseViewModel();
    
    // 最初のカメラ（通常は背面カメラ）を使ってストリームを開始
    if (widget.cameras.isNotEmpty) {
      _viewModel.initializeCamera(widget.cameras.first);
    }
  }

  @override
  void dispose() {
    // 画面が破棄される際に、ViewModel内のカメラやML Kitのリソースを解放 
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          
          // カメラの準備がまだできていない場合はローディングを表示
          if (_viewModel.cameraController == null ||
              !_viewModel.cameraController!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. プレビュー画面: カメラ映像を全画面表示
              CameraPreview(_viewModel.cameraController!),

              // 2. 検知フィードバック (枠線)
              // _viewModel.isHandRaised の値に応じて色を切り替える
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _viewModel.isHandRaised ? Colors.red : Colors.blue,
                    width: 8.0,
                  ),
                ),
              ),

              // 3. 検知時のテキスト表示
              if (_viewModel.isHandRaised)
                Positioned(
                  top: 80, // 上部のセーフエリアを考慮して少し下げる
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red.withOpacity(0.7),
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      '挙手検知中',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}