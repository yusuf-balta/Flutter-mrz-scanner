import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_ml_vision/google_ml_vision.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MrzDataPassport? mrzDataPassport;
  MrzDataTc? mrzDataTc;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text("Mrz Scanner")),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 25),
            child: Column(
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      mrzDataTc = await Get.to(
                        const MrzScanner(
                          isTc: true,
                        ),
                      );
                      setState(() {});
                    },
                    child: Text("Start Scanning for TC ID"),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    mrzDataPassport = await Get.to(
                      const MrzScanner(
                        isTc: false,
                      ),
                    );
                    setState(() {});
                  },
                  child: Text("Start Scanning for Passport"),
                ),
                SizedBox(
                  height: 25,
                ),
                if (mrzDataPassport != null) ...[
                  Text("Passport Scanned Data",
                      style: Theme.of(context).textTheme.bodyLarge),
                  customH,
                  ...showPassportData
                ],
                SizedBox(
                  height: 25,
                ),
                if (mrzDataTc != null) ...[
                  Text("TC Id Scanned Data",
                      style: Theme.of(context).textTheme.bodyLarge),
                  customH,
                  ...showTcData
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> get showPassportData => [
        dualText(key: "passport no", value: mrzDataPassport!.passportNo ?? ""),
        customH,
        dualText(key: "birth date", value: mrzDataPassport!.birthDate ?? ""),
        customH,
        dualText(key: "name", value: mrzDataPassport!.name ?? ""),
        customH,
        dualText(key: "sur name", value: mrzDataPassport!.surname ?? ""),
        customH,
        dualText(key: "sex ", value: mrzDataPassport!.sex ?? ""),
        customH,
        dualText(
            key: "nationality ", value: mrzDataPassport!.nationality ?? ""),
      ];
  List<Widget> get showTcData => [
        dualText(key: "tc no", value: mrzDataTc!.tcNo ?? ""),
        customH,
        dualText(key: "name", value: mrzDataTc!.name ?? ""),
        customH,
        dualText(key: "sur name", value: mrzDataTc!.surname ?? ""),
      ];

  Widget get customH => SizedBox(
        height: 25,
      );

  Widget dualText({required String key, required String value}) {
    return Row(
      children: [
        Text(key + " :"),
        Text(value),
      ],
    );
  }
}

class MrzScanner extends StatefulWidget {
  static String routeName = "/app-mrz-scanner";
  const MrzScanner({
    Key? key,
    this.isTc = false,
  }) : super(key: key);

  final bool isTc;

  @override
  _MrzScannerState createState() => _MrzScannerState();
}

class _MrzScannerState extends State<MrzScanner> {
  late List<CameraDescription> _cameras;
  late CameraController controller;
  bool isBusy = false;
  bool isInit = false;
  final TextRecognizer textRecognizer = GoogleVision.instance.textRecognizer();

  final RxString _passportHintTop = "X<XXXXX<<XXXXX<<<<<<<<<<<<<<<<<<<".obs;
  String get passportHintTop => _passportHintTop.value;
  setPassportHintTop(value) => _passportHintTop.value = value;

  final RxString _passportHintBottom =
      "L898902C36UTO7408122F1204159ZE184226B<<<<<10".obs;
  String get passportHintBottom => _passportHintBottom.value;
  setPassportHintBottom(value) => _passportHintBottom.value = value;

  final RxString _tcHintTop = "X<XXXXXXXXXXXXX<XXXXXXXXXXX<<<".obs;
  String get tcHintTop => _tcHintTop.value;
  setTcHintTop(value) => _tcHintTop.value = value;

  final RxString _tcHintMid = "XXXXXXXXXXXXXXXXXXX<<<<<<<<<<<2".obs;
  String get tcHintMid => _tcHintMid.value;
  setTcHintMid(value) => _tcHintMid.value = value;

  final RxString _tcHintBot = "XXXXX<<XXXX<<<<<<<<<<<<<<<".obs;
  String get tcHintBot => _tcHintBot.value;
  setTcHintBot(value) => _tcHintBot.value = value;

  List<Rect?> listRect = <Rect>[].obs;
  late Size size;
  Future<void> init() async {
    try {
      _cameras = await availableCameras();
      log(_cameras.first.name);
      controller = CameraController(
        _cameras[0],
        Platform.isIOS ? ResolutionPreset.medium : ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      controller.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        isInit = controller.value.isInitialized;
        setState(() {});
        await setStream();
      }).catchError((Object e) {
        if (e is CameraException) {
          switch (e.code) {
            case 'CameraAccessDenied':
              log('User denied camera access.');

              break;
            default:
              log('Handle other errors.');
              break;
          }
        }
      });
    } catch (e) {
      log(e.toString());
    }
  }

  @override
  void initState() {
    log("init");
    super.initState();
    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    } else if (Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
      ]);
    }

    init();
  }

  Future<void> setStream() async {
    await controller.startImageStream(
      (image) => !isBusy
          ? scanText(image)
          : () {
              log(
                "isBusy",
              );
            },
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    controller.dispose();
    log("dispose");
    super.dispose();
  }

  disposeController() async {
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    await textRecognizer.close();
  }

  final TextStyle style = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      color: Colors.black.withOpacity(0.3));
  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          if (isInit) ...[
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(
                  controller,
                ),
              ),
            )
          ],
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20 * 2,
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Get.back();
                          },
                          child: Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.isTc) ...[
                      Text(
                        tcHintTop,
                        style: style,
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        tcHintMid,
                        style: style,
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        tcHintBot,
                        style: style,
                      ),
                    ] else ...[
                      Text(
                        passportHintTop,
                        style: style,
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        passportHintBottom,
                        style: style,
                      ),
                    ],
                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Obx(
              () => Stack(
                children: List.generate(
                  listRect.length,
                  (index) => Positioned.fromRect(
                    rect:
                        listRect[index] ?? const Rect.fromLTRB(12, 33, 44, 66),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.green,
                          width: 1.5,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> scanText(
    CameraImage xfile,
  ) async {
    log("start");
    isBusy = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in xfile.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final Size imageSize =
          Size(xfile.width.toDouble(), xfile.height.toDouble());
      final inputImageFormat = xfile.format.raw;
      final planeData = xfile.planes.map(
        (Plane plane) {
          return GoogleVisionImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList();

      final inputImageData = GoogleVisionImageMetadata(
        size: imageSize,
        // rotation: imageRotation,
        rawFormat: inputImageFormat,
        planeData: planeData,
        rotation: ImageRotation.rotation0,
      );

      final GoogleVisionImage visionImage = GoogleVisionImage.fromBytes(
        bytes,
        inputImageData,
      );

      final VisionText visionText =
          await textRecognizer.processImage(visionImage);
      int length = visionText.blocks.length;
      log(visionText.text ?? "");

      listRect.clear();
      for (var e1 in visionText.blocks) {
        for (var e2 in e1.lines) {
          listRect.add(
            Rect.fromLTRB(
              fixW(e2.boundingBox?.left),
              fixH(e2.boundingBox?.top),
              fixW(e2.boundingBox?.right),
              fixH(e2.boundingBox?.bottom),
            ),
          );
        }
      }
      if (widget.isTc) {
        if (Platform.isAndroid) {
          if (await checkDataTc(
            visionText.blocks[length - 3].text,
            visionText.blocks[length - 2].text,
            visionText.blocks[length - 1].text,
          )) {
            return;
          }
        } else if (Platform.isIOS) {
          if (await checkDataTc(
            visionText.blocks[length - 1].lines[0].text,
            visionText.blocks[length - 1].lines[1].text,
            visionText.blocks[length - 1].lines[2].text,
          )) {
            return;
          }
        }
      } else {
        if (await checkDataPassport(
          visionText.blocks[length - 2].text ?? "",
          visionText.blocks[length - 1].text ?? "",
        )) {
          return;
        }
      }
    } catch (e) {
      log(e.toString());
    }
    isBusy = false;

    log("end");
  }

  Future<bool> checkDataTc(
    String? top,
    String? mid,
    String? bot,
  ) async {
    if (top == null || mid == null || bot == null) {
      return false;
    }
    top = top.split(" ").join();
    mid = mid.split(" ").join();
    bot = bot.split(" ").join();
    top = fixText(top.split(" ").join());
    mid = fixText(mid.split(" ").join());
    bot = fixText(bot.split(" ").join());
    setTcHintTop(top);
    setTcHintMid(mid);
    setTcHintBot(bot);
    if (bot.length != 30 || top.length != 30 || bot.length != 30) {
      return false;
    }
    if (top.split("")[1] != "<") {
      return false;
    }
    if (!mid.contains("<<<<<<<<<")) {
      return false;
    }
    if (!top.contains("<<<")) {
      return false;
    }
    if (!bot.contains("<<<<<<<<<<<")) {
      return false;
    }
    await disposeController();
    final mrzData = MrzDataTc().fromMrz(top: top, mid: mid, bot: bot);
    Get.back(result: mrzData);
    Get.snackbar("Succses", "");
    return true;
  }

  double fixW(double? value) {
    value = value ?? 0;
    double imageW = Platform.isIOS ? 640 : 1280;
    double deviceWidth = size.width;
    return (value * deviceWidth) / imageW;
  }

  double fixH(double? value) {
    value = value ?? 0;
    double imageH = Platform.isIOS ? 480 : 720;
    double deviceHeigh = size.height;
    return (value * deviceHeigh) / imageH;
  }

  Future<bool> checkDataPassport(
    String? top,
    String? bottom,
  ) async {
    if (bottom == null || top == null) {
      return false;
    }
    top = fixText(top);
    bottom = bottom.split(" ").join();
    log(
      top.length.toString(),
    );
    setPassportHintBottom(bottom);
    setPassportHintTop(top);

    if (bottom.length != 44 || top.length != 44) {
      return false;
    }
    if (!top.contains("<<<<<<<<<<")) {
      return false;
    }
    await disposeController();
    final mrzData = MrzDataPassport().fromMrz(top, bottom);
    Get.back(result: mrzData);
    Get.snackbar("Succses", "");
    return true;
  }

  String fixText(String value) {
    String returnValue = "";
    List<String> splitValue = value.split("");
    for (int i = 0; i < returnValue.length; i++) {
      if (splitValue[i] == "K" || splitValue[i] == "k") {
        splitValue[i] = "<";
      } else if (splitValue[i] == "«") {
        splitValue[i] = "<";
      } else {
        continue;
      }
    }
    returnValue = splitValue.join();

    return returnValue;
  }
}

class MrzDataPassport {
  String? passportNo;
  String? birthDate;
  String? nationality;
  String? sex;
  String? name;
  String? surname;

  MrzDataPassport({
    this.passportNo,
    this.birthDate,
    this.nationality,
    this.sex,
    this.name,
    this.surname,
  });

  MrzDataPassport fromMrz(String top, String bottom) {
    return MrzDataPassport(
      name: _setName(top),
      surname: _setSurname(top),
      nationality: _setNatinolaty(top),
      passportNo: _setPassport(bottom),
      birthDate: _setBirthDate(bottom),
      sex: _setSex(bottom),
    );
  }

  String? _setName(String top) {
    return top.split("<<")[1].toUpperCase();
  }

  String? _setSurname(String top) {
    List<String> listString = top.split("<");
    String lastNameTemp = listString[1];
    List<String> lastNameList = lastNameTemp.split("");
    String lastname = lastNameList.getRange(3, lastNameList.length).join();
    return lastname.toUpperCase();
  }

  String? _setNatinolaty(String top) {
    List<String> listString = top.split("<");
    String natinolatiyTemp = listString[1];
    List<String> natinolatiyList = natinolatiyTemp.split("");
    String natinolatiy = natinolatiyList.getRange(0, 3).join();
    return natinolatiy.toUpperCase();
  }

  String? _setPassport(String bottom) {
    List<String> listString = bottom.split("");
    return listString.getRange(0, 9).join().toUpperCase();
  }

  String? _setBirthDate(String bottom) {
    List<String> listString = bottom.split("");
    String year = listString.getRange(13, 15).join();
    String mounth = listString.getRange(15, 17).join();
    String day = listString.getRange(17, 19).join();
    return "$day-$mounth-19$year".toUpperCase();
  }

  String? _setSex(String bottom) {
    List<String> listString = bottom.split("");
    return listString[20].toUpperCase();
  }
}

class MrzDataTc {
  String? tcNo;
  String? birthDate;
  String? nationality;
  String? sex;
  String? name;
  String? surname;
  MrzDataTc({
    this.tcNo,
    this.birthDate,
    this.nationality,
    this.sex,
    this.name,
    this.surname,
  });

  MrzDataTc fromMrz({
    required String top,
    required String mid,
    required String bot,
  }) {
    return MrzDataTc(
      tcNo: _setTcNo(top: top),
      name: _setName(bot: bot),
      surname: _setSurName(bot: bot),
    );
  }

  String _setSurName({required String bot}) {
    return bot.split("<").first;
  }

  String _setName({required String bot}) {
    return bot.split("<")[2];
  }

  String _setTcNo({required String top}) {
    return top.split("<")[2];
  }
}
