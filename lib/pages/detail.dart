import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:ClippingKK/model/doubanBookInfo.dart';
import 'package:ClippingKK/repository/douban.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ClippingKK/model/httpResponse.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

const _defaultBackgroundImage =
    'https://kindle.annatarhe.com/coffee-d3ec79a0efd30ac2704aa2f26e72cb28.jpg';

const CANVAS_HEIGHT = 640.0;
const CANVAS_WIDTH = 320.0;

// Flutter 尚不支持命名路由, 所以没能加入到根路由上
class DetailPage extends StatefulWidget {
  final ClippingItem item;

  DetailPage({@required this.item});

  @override
  DetailPageState createState() {
    return new DetailPageState();
  }
}

class DetailPageState extends State<DetailPage> {
  DoubanBookInfo _bookInfo;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  void _loadInfo() async {
    final info = await DoubanAPI().search(widget.item.title);
    setState(() {
      _bookInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundImage =
        _bookInfo != null ? _bookInfo.image : _defaultBackgroundImage;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
      ),
      body: Container(
        // height: MediaQuery.of(context).size.height,
        // width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            image: DecorationImage(
                image: NetworkImage(backgroundImage), fit: BoxFit.cover)),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
            child: Center(
                child: Card(
                    margin: const EdgeInsets.all(20.0),
                    child: Center(
                        child: Container(
                            margin: const EdgeInsets.all(10.0),
                            child: Column(
                              children: <Widget>[
                                Image.network(backgroundImage, width: 154.0, height: 218.0),
                                Text(widget.item.content),
                                _ImageCanvas(bookInfo: _bookInfo),
                              ],
                            )))))),
      ),
    );
  }
}

class _ImageCanvas extends StatefulWidget {
  _ImageCanvas({
    Key key,
    this.bookInfo
  }) : super(key: key);

  DoubanBookInfo bookInfo;

  @override
  _ImageCanvasState createState() {
    return new _ImageCanvasState();
  }
}

class _ImageCanvasState extends State<_ImageCanvas> {
  static const platform =
      const MethodChannel('com.annatarhe.clippingkk/channel');

  bool _loading = true;
  ByteData _img;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    this._buildImage();
  }

  void _buildImage() async {
    final recorder = new PictureRecorder();
    final canvas = new Canvas(recorder,
        new Rect.fromPoints(new Offset(0.0, 0.0), new Offset(CANVAS_WIDTH, CANVAS_HEIGHT)));
    
    final paint = new Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, CANVAS_WIDTH, CANVAS_HEIGHT), paint);

    final _paragraph = ParagraphBuilder(
        ParagraphStyle(textAlign: TextAlign.left, fontSize: 24.0)
      );
    _paragraph.addText('hello');
    final p = _paragraph.build();
    p.layout(ParagraphConstraints(width: 100.0));
    final bg = await this._loadImage();
    // not working
    canvas.drawImage(bg, Offset(20.0, 20.0), paint);
    canvas.drawParagraph(p, Offset(30.0, 30.0));

    final picture = recorder.endRecording();
    // final pngBytes = await picture.toImage(CANVAS_WIDTH ~/ 2, CANVAS_HEIGHT ~/ 2).toByteData(format: ImageByteFormat.png);
    final pngBytes = await picture.toImage(CANVAS_WIDTH ~/ 4, CANVAS_HEIGHT ~/ 4).toByteData(format: ImageByteFormat.png);

    if (!this.mounted) {
      return;
    }

    setState(() {
      _img = pngBytes;
      _loading = false;
    });
    // await platform.invokeMethod("saveImage", {'image': pngBytes.buffer.asUint8List()});
  }

  Future<ui.Image> _loadImage() async {
    final _image = await http.readBytes(_defaultBackgroundImage);

    final bg = await ui.instantiateImageCodec(_image);
    final frame = await bg.getNextFrame();
    final img = frame.image;
    print(img.width);
    print(img.height);
    return img;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _img == null) {
      return Text('loading');
    }
    return Image.memory(new Uint8List.view(this._img.buffer));
  }
}