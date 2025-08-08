import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/firebase_options.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => TeamProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      home: const TeamSelectPage(),
    );
  }
}
