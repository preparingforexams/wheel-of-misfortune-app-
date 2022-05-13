import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/bloc.dart';
import 'package:misfortune_app/client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
      home: const BlocPage(),
    );
  }
}

class BlocPage extends StatelessWidget {
  const BlocPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MisfortuneBloc>(
      create: (context) => MisfortuneBloc(HttpMisfortuneClient()),
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
      bottomNavigationBar: Center(
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
          case Stage.awaitingPress:
            return ElevatedButton(
              onPressed: () => bloc.add(SubscribeEvent()),
              child: const Text("Ich habe Durst"),
            );
          case Stage.awaitingSpin:
            return Column(
              children: [
                const Text("Dreh das Rad!"),
                if (state.tooSlow) const Text("Schneller!")
              ],
            );
          case Stage.failed:
            return const Text("Konnte das Rad nicht drehen ð");
          case Stage.spinning:
            return const Text("Prost!");
        }
      },
    );
  }
}
