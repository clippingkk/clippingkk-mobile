import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:core';
import 'dart:async';
import 'package:ClippingKK/components/clipping-content-text.dart';
import 'package:ClippingKK/model/doubanBookInfo.dart';
import 'package:ClippingKK/repository/douban.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ClippingKK/model/httpResponse.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image/image.dart' as imgPack;
import '../utils/logger.dart';

const _shareBackgroundImages = [
  'https://ws1.sinaimg.cn/large/8112eefdgy1g08jm3nz77j20u01hcdr5.jpg',
  'https://ws1.sinaimg.cn/large/8112eefdgy1g08jm3e6h1j20u01hcdpm.jpg',
  'https://ws1.sinaimg.cn/large/8112eefdgy1g08jm435utj20u01hcgwg.jpg',
  'https://ws1.sinaimg.cn/large/8112eefdgy1g08jm47mh2j20u01hc4dq.jpg',
];

const _websiteQRCode = 'https://kindle.annatarhe.com/website-qrcode-6881260f2987665566b88c7cd62746f7.png';

const _defaultBackgroundImage =
  'https://ws1.sinaimg.cn/large/8112eefdgy1g08jm47mh2j20u01hc4dq.jpg';

const CANVAS_HEIGHT = 1920.0;
const CANVAS_WIDTH = 1080.0;

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
  static const platform =
      const MethodChannel('com.annatarhe.clippingkk/channel');

  static GlobalKey previewContainer = new GlobalKey();

  DoubanBookInfo _bookInfo;
  ByteData png;

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

  void _saveScreenshot(BuildContext context) async {
    _ShareImageRender shareImage = _ShareImageRender(
      author: this._bookInfo.author,
      content: this.widget.item.content,
      bookTitle: this.widget.item.title
    );
    final image = await shareImage.buildImage();

    setState(() {
      png = image;
    });
    await shareImage.saveImage(image);

    Scaffold.of(context).showSnackBar(SnackBar(content: Text('done~')));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundImage =
        _bookInfo != null ? _bookInfo.image : _defaultBackgroundImage;
    final author = _bookInfo != null ? _bookInfo.author : '佚名';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
        actions: <Widget>[
          IconButton(icon: Icon(Icons.image),
            onPressed: () => this._saveScreenshot(context))
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(backgroundImage), fit: BoxFit.cover)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.1)),
              ),
            ),
          ),
          Container(
            child: Container(
              alignment: Alignment.center,
              child: Card(
                margin: const EdgeInsets.all(40.0),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ClippingContentText(
                    content: this.widget.item.content,
                    author: author)
                ))),
          )
        ],
      ),
    );
  }
}

// flutter 的 canvas 不能在 gpu 情况下正常渲染 drawImage
// https://github.com/flutter/flutter/issues/23621
class _ShareImageRender {
  static const platform =
      const MethodChannel('com.annatarhe.clippingkk/channel');

  final grep = 100.0;

  final String author;
  final String content;
  final String bookTitle;

  _ShareImageRender({
    @required this.author,
    @required this.content,
    @required this.bookTitle
  });

  Future<ui.Image> _loadImageAssets(String url) async {
    final _image = await http.readBytes(url);

    final bg = await ui.instantiateImageCodec(_image);
    final frame = await bg.getNextFrame();
    final img = frame.image;
    return img;
  }

  Future<ByteData> buildImage() async {
    final recorder = new ui.PictureRecorder();
    final canvas = new Canvas(
        recorder,
        Rect.fromPoints(
            Offset(0.0, 0.0),
            Offset(CANVAS_WIDTH, CANVAS_HEIGHT)
        )
    );

    final responses = await Future.wait([
      this._loadImageAssets(_defaultBackgroundImage),
      this._loadImageAssets(_websiteQRCode)
    ]);
    final _paragraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: 64.0));
    _paragraph.addText(this.content);
    final p = _paragraph.build();
    p.layout(ui.ParagraphConstraints(width: CANVAS_WIDTH - grep * 2));
    canvas.drawImage(responses[0], Offset.zero, Paint());
    canvas.drawParagraph(p, Offset(grep, grep));

    final bookText = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: 48.0)
    );
    bookText.addText(this.bookTitle + '\n' + this.author);
    final bookTextParagraph = bookText.build();
    bookTextParagraph.layout(
      ui.ParagraphConstraints(width: CANVAS_WIDTH - grep * 2));
    canvas.drawParagraph(
      bookTextParagraph, Offset(grep, CANVAS_HEIGHT - grep * 4));

    canvas.drawImageRect(
      responses[1],
      Rect.fromLTWH(
        0, 0, responses[1].width.toDouble(), responses[1].height.toDouble()),
      Rect.fromLTWH(CANVAS_WIDTH - 250, CANVAS_HEIGHT - 200, 150, 150),
      Paint());

    final picture = recorder.endRecording();
    final pngBytes = (
      await picture
        .toImage(CANVAS_WIDTH ~/ 1, CANVAS_HEIGHT ~/ 1)
    ).toByteData(format: ui.ImageByteFormat.png);

    return pngBytes;
  }

  Future<dynamic> saveImage(ByteData pngBytes) {
    return platform
        .invokeMethod("saveImage", {'image': pngBytes.buffer.asUint8List()});
  }
}
