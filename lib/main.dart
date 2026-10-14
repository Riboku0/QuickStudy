
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'study_page.dart';
import 'library_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int selectedIndex = 0;

  final pages = const [
    HomePage(),
    StudyPage(),
    LibraryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: pages[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'Study',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'Library',
            ),
          ],
        ),
      ),
    );
  }
}
