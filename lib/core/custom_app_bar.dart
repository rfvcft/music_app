import 'package:flutter/material.dart';
import 'package:music_app/utils/conversion.dart' as conv;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 18, 18, 18),
      iconTheme: IconThemeData(color: Colors.grey[400]),
      elevation: 8,
      shadowColor: Colors.grey[700],
      title: Text(
        title,
        style: TextStyle(color: Colors.grey[400]),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          color: conv.infernoColormap(0.7),
          height: 2,
        ),
      ),
    );
  }
}