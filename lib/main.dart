import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(MyApp(code: Uri.base.queryParameters["code"]));
}

class MyApp extends StatelessWidget {
  final String? code;

  const MyApp({
    Key? key,
    required this.code,
  }) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheel',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: BlocPage(code: code),
    );
  }
}

class BlocPage extends StatelessWidget {
  final String? code;

  const BlocPage({
    Key? key,
    required this.code,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MisfortuneBloc>(
      create: (context) => MisfortuneBloc(
        client: HttpMisfortuneClient(),
        code: code,
      ),
      child: const MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: DefaultTextStyle(
          style: TextStyle(fontSize: 48),
          child: SpinContent(),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 20,
        child: Center(
          child: BlocBuilder<MisfortuneBloc, MisfortuneState>(
            builder: (context, state) {
              final movement = state.movement;
              if (movement == null) {
                return const Offstage();
              } else {
                return Text(movement);
              }
            },
          ),
        ),
      ),
    );
  }
}

class SpinContent extends StatelessWidget {
  const SpinContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MisfortuneBloc, MisfortuneState>(
      builder: (context, state) {
        final bloc = BlocProvider.of<MisfortuneBloc>(context);
        switch (state.stage) {
          case Stage.wrongBrowser:
            return const Text(
              "Leider funktioniert diese Webseite nur in Google Chrome",
            );
          case Stage.awaitingPress:
            return ElevatedButton(
              style: ButtonStyle(
                padding: MaterialStateProperty.all(const EdgeInsets.all(25)),
              ),
              onPressed: () => bloc.add(PressButtonEvent()),
              child: Text(
                "Ich habe Durst",
                style: DefaultTextStyle.of(context).style,
              ),
            );
          case Stage.scanningCode:
            return const QrScanner();
          case Stage.awaitingSpin:
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Dreh das Rad!"),
                if (state.tooSlow) const Text("Schneller!")
              ],
            );
          case Stage.failed:
            return Text("Konnte das Rad nicht drehen 😢 (${state.error})");
          case Stage.spinning:
            return const Text("Prost!");
        }
      },
    );
  }
}

class QrScanner extends StatefulWidget {
  const QrScanner({Key? key}) : super(key: key);

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<MisfortuneBloc>(context);
    return MobileScanner(
      onDetect: (barcode, args) {
        final String url;
        if (barcode.type == BarcodeType.url) {
          final rawUrl = barcode.url?.url;
          if (rawUrl == null) {
            return;
          }
          url = rawUrl;
        } else if (barcode.type == BarcodeType.text) {
          final rawValue = barcode.rawValue;
          if (rawValue == null) {
            return;
          }
          url = rawValue;
        } else {
          return;
        }

        final uri = Uri.tryParse(url);
        if (uri == null) {
          return;
        }

        if (uri.authority == "bembel.party") {
          final code = uri.queryParameters["code"];
          if (code != null) {
            bloc.add(ScanQrEvent(code));
          }
        }
      },
      controller: _controller,
    );
  }
}
