import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:mojo/application.dart';
import 'package:mojo/core.dart' as mojo;
import 'package:mojo/mojo/service_provider.mojom.dart' as mojom;
import 'package:mojo/mojo/shell.mojom.dart' as mojom;
import 'package:mojo/mojo/url_request.mojom.dart' as mojom;
import 'package:mojo/mojo/url_response.mojom.dart' as mojom;
import 'package:mojo_services/mojo/network_service.mojom.dart' as mojom;
import 'package:mojo_services/mojo/url_loader.mojom.dart' as mojom;

mojom.NetworkServiceProxy networkServiceProxy = _initNetworkServiceProxy();
mojom.NetworkServiceProxy _initNetworkServiceProxy() {
  mojom.Shell shell;
  mojo.MojoHandle shellHandle = new mojo.MojoHandle(MojoServices.takeShell());
  if (shellHandle.isValid)
    shell = new mojom.ShellProxy.fromHandle(shellHandle).ptr;

  ApplicationConnection embedder;
  mojo.MojoHandle incomingServicesHandle = new mojo.MojoHandle(MojoServices.takeIncomingServices());
  mojo.MojoHandle outgoingServicesHandle = new mojo.MojoHandle(MojoServices.takeOutgoingServices());
  if (incomingServicesHandle.isValid && outgoingServicesHandle.isValid) {
    mojom.ServiceProviderProxy incomingServices = new mojom.ServiceProviderProxy.fromHandle(incomingServicesHandle);
    mojom.ServiceProviderStub outgoingServices = new mojom.ServiceProviderStub.fromHandle(outgoingServicesHandle);
    embedder = new ApplicationConnection(outgoingServices, incomingServices);
  }

  assert(shell != null || embedder != null);

  mojom.NetworkServiceProxy result = new mojom.NetworkServiceProxy.unbound();
  if (shell != null) {
    mojom.ServiceProviderProxy services = new mojom.ServiceProviderProxy.unbound();
    shell.connectToApplication('mojo:authenticated_network_service', services, null);
    mojo.MojoMessagePipe pipe = new mojo.MojoMessagePipe();
    result.impl.bind(pipe.endpoints[0]);
    services.ptr.connectToService(result.serviceName, pipe.endpoints[1]);
    services.close();
  } else if (embedder != null) {
    embedder.requestService(result);
  }
  return result;
}

void fetchImage(String url, void callback(Image image)) {
  mojom.UrlRequest request = new mojom.UrlRequest()
    ..url = Uri.base.resolve(url).toString()
    ..autoFollowRedirects = true;
  mojom.UrlLoaderProxy loader = new mojom.UrlLoaderProxy.unbound();
  networkServiceProxy.ptr.createUrlLoader(loader);
  loader.ptr.start(request).then((mojom.UrlLoaderStartResponseParams result) {
    mojom.UrlResponse response = result.response;
    if (response.statusCode != 200)
      return null;
    decodeImageFromDataPipe(response.body.handle.h, callback);
  });
}

class Text {
  Text({ String text, TextStyle textStyle, ParagraphStyle paragraphStyle }) {
    ParagraphBuilder p = new ParagraphBuilder();
    if (textStyle != null)
      p.pushStyle(textStyle);
    p.addText(text);
    _paragraph = p.build(paragraphStyle ?? new ParagraphStyle());
  }

  Paragraph _paragraph;

  double _currentWidth;
  void _layout(double width) {
    assert(width != null);
    if (_currentWidth == width)
      return;
    _currentWidth = width;
    _paragraph.maxWidth = width;
    _paragraph.layout();
  }

  double _naturalMaxWidth;
  double _naturalMinWidth;
  void _ensureNaturalWidths() {
    if (_naturalMinWidth == null) {
      assert(_naturalMaxWidth == null);
      _layout(double.INFINITY);
      _naturalMinWidth = _paragraph.minIntrinsicWidth;
      _naturalMaxWidth = _paragraph.maxIntrinsicWidth;
    }
    assert(_naturalMinWidth != null);
    assert(_naturalMaxWidth != null);
  }
  double get naturalMaxWidth {
    _ensureNaturalWidths();
    return _naturalMaxWidth.ceilToDouble();
  }
  double get naturalMinWidth {
    _ensureNaturalWidths();
    return _naturalMinWidth.ceilToDouble();
  }

  double actualHeight(double width) {
    _layout(width);
    return _paragraph.height.ceilToDouble();
  }

  void paint(Canvas canvas, Rect rect) {
    _layout(rect.width);
    canvas.drawParagraph(_paragraph, rect.topLeft.toOffset());
  }
}

const double captionSize = 24.0;
const double tableTextSize = 16.0;
const double horizontalPadding = 4.0;
const double verticalPadding = 8.0;

class Train {
  Train(
    String code,
    String imageUrl,
    String description
  ) : code = new Text(
        text: code,
        textStyle: new TextStyle(
          fontSize: tableTextSize,
          color: const Color(0xFF004D40)
        )
      ),
      description = new Text(
        text: description,
        textStyle: new TextStyle(
          fontSize: tableTextSize,
          color: const Color(0xFF004D40)
        )
      ) {
    fetchImage(imageUrl, (Image resolvedImage) {
      image = resolvedImage;
      window.scheduleFrame();
    });
  }
  final Text code;
  Image image;
  final Text description;
}

final List<Train> kTrainData = <Train>[
  new Train('49954', 'https://static.maerklin.de/media/bc/02/bc028d6e5f98ccaeb344118d64927edd1451859002.jpg', 'Type 100 crane car and type 817 boom tender car.'),
  new Train('26602', 'https://static.maerklin.de/media/cc/b9/ccb96e67093f188d67acb4ca97b407da1452597002.jpg', 'Class Köf II Diesel Locomotive with stake cars loaded with bricks and construction steel mats.'),
  new Train('46925', 'https://static.maerklin.de/media/ad/3f/ad3fa11c35f10737cb54320b9e5c006a1451857433.jpg', 'Set with 2 Type Kbs Stake Cars transporting brewery tanks (storage tanks).'),
  new Train('46870', 'https://static.maerklin.de/media/ed/36/ed365bf5b8c89cc63d54afa81db80df01451857433.jpg', 'Swiss Federal Railways (SBB) four-axle flat cars with telescoping covers loaded with coils.'),
  new Train('47724', 'https://static.maerklin.de/media/20/fe/20fe74d67d07417352fd08b164f271c41451859002.jpg', 'Swedish State Railways (SJ) two-axle container transport cars loaded with two "Inno freight" WoodTainer XXL containers, painted and lettered for "green cargo".'),
  new Train('47319', 'https://static.maerklin.de/media/6e/32/6e32c9c7153637b9e0d484a1958703191451859002.jpg', 'Stake cars with steel and pipe.'),
];

final Text title = new Text(
  text: 'My 2016 Märklin Trains Wishlist',
  textStyle: new TextStyle(fontSize: captionSize, color: const Color(0xFF4CAF50)),
  paragraphStyle: new ParagraphStyle(textAlign: TextAlign.center)
);

void render(Duration duration) {
  final Rect bounds = Point.origin & window.size;
  final PictureRecorder recorder = new PictureRecorder();
  final Canvas c = new Canvas(recorder, bounds);
  Paint background = new Paint()
    ..color = const Color(0xFFFFFFFF);
  c.drawPaint(background);

  final double width = window.size.width - window.padding.left - window.padding.right;

  title.paint(c, new Rect.fromLTWH(
    window.padding.left,
    window.padding.top + verticalPadding,
    width,
    captionSize
  ));

  final List<double> columnWidths = new List<double>.filled(3, 0.0);
  for (int index = 0; index < kTrainData.length; index += 1) {
    Train train = kTrainData[index];
    columnWidths[0] = math.max(columnWidths[0], train.code.naturalMaxWidth + horizontalPadding * 2.0);
    columnWidths[1] = math.max(columnWidths[1], (train.image?.width ?? 0.0) + horizontalPadding * 2.0);
    columnWidths[2] = math.max(columnWidths[2], train.description.naturalMaxWidth + horizontalPadding * 2.0);
  }
  // make the image column max 40% (and take into account the device pixel ratio)
  columnWidths[1] = math.min(columnWidths[1] / window.devicePixelRatio, width * 0.4);
  columnWidths[2] = width - (columnWidths[0] + columnWidths[1]);

  double y = window.padding.top + verticalPadding + captionSize + verticalPadding;
  for (int index = 0; index < kTrainData.length; index += 1) {
    final Train train = kTrainData[index];
    y += verticalPadding;
    double x = window.padding.left;
    train.code.paint(c, new Rect.fromLTWH(x + horizontalPadding, y + verticalPadding, columnWidths[0] - horizontalPadding * 2.0, tableTextSize));
    final double rowHeight = math.max(train.description.actualHeight(columnWidths[2] - horizontalPadding * 2.0), tableTextSize);
    x += columnWidths[0];
    if (train.image != null) {
      final Rect destRect = new Rect.fromLTWH(x, y, columnWidths[1], rowHeight + verticalPadding * 2.0);
      final double sourceHeight = train.image.width.toDouble() * destRect.height / destRect.width;
      final Rect sourceRect = new Rect.fromLTWH(
        0.0,
        (train.image.height.toDouble() - sourceHeight) / 2.0,
        train.image.width.toDouble(),
        sourceHeight
      );
      c.drawImageRect(train.image, sourceRect, destRect, null);
    }
    x += columnWidths[1];
    train.description.paint(c, new Rect.fromLTWH(x + horizontalPadding, y + verticalPadding, columnWidths[2] - horizontalPadding * 2.0, rowHeight));
    y += rowHeight + verticalPadding * 2.0;
  }

  // XXX draw lines

  Picture picture = recorder.endRecording();
  SceneBuilder builder = new SceneBuilder();
  builder.pushTransform(new Float64List.fromList(
    <double>[window.devicePixelRatio, 0.0, 0.0, 0.0,
             0.0, window.devicePixelRatio, 0.0, 0.0,
             0.0, 0.0, 1.0, 0.0,
             0.0, 0.0, 0.0, 1.0]
  ));
  builder.addPicture(Offset.zero, picture);
  Scene scene = builder.build();
  window.render(scene);
}

void main() { 
  window.onBeginFrame = render;
  window.onMetricsChanged = window.scheduleFrame;
  window.scheduleFrame();
}
