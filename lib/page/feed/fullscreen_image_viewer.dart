import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<TransformationController> _transformationControllers;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationControllers = List.generate(
      widget.imageUrls.length,
      (index) => TransformationController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetZoom(int index) {
    if (index >= 0 && index < _transformationControllers.length) {
      _transformationControllers[index].value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          // 이전 페이지의 줌 초기화
          if (index > 0) _resetZoom(index - 1);
          if (index < widget.imageUrls.length - 1) _resetZoom(index + 1);
        },
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onDoubleTap: () {
              final controller = _transformationControllers[index];
              if (controller.value.getMaxScaleOnAxis() == 1.0) {
                controller.value = Matrix4.identity()
                  ..translate(0.0, 0.0)
                  ..scale(2.0);
              } else {
                controller.value = Matrix4.identity();
              }
            },
            child: InteractiveViewer(
              transformationController: _transformationControllers[index],
              minScale: 0.8,
              maxScale: 3.0,
              child: Center(
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 50,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '이미지를 불러올 수 없습니다',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
