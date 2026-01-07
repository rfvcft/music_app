
import 'package:flutter/material.dart';

import 'package:music_app/screens/archive.dart';
import 'package:music_app/screens/audio.dart';
import 'package:music_app/screens/import.dart';
import 'package:music_app/screens/load_assets.dart';
import 'package:music_app/utils/conversion.dart' as conv;

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;
  
  Widget _title() {
    // DODECA title and MELODY DETECTION subtitle, perfectly centered and aligned
    final dodecaText = 'DODECA';
    final dodecaStyle = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.normal,
      letterSpacing: 18,
      color: Colors.black,
      shadows: [
        Shadow(
          blurRadius: 15,
          color: Colors.white,
          offset: Offset(2, 4),
        ),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: dodecaText, style: dodecaStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dodecaWidth = tp.width;
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: dodecaWidth,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                int numColors = 10;
                double start = 0.5;
                double end = 0.8;
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: List.generate(
                    numColors,
                    (i) => conv.infernoColormap(start + (end - start) * (numColors - i - 1) / (numColors - 1)),
                  ),
                ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                dodecaText,
                style: dodecaStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: SizedBox(
            width: dodecaWidth,
            child: Text(
              'MELODY DETECTION',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                letterSpacing: 4,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageButton(BuildContext context, String title, Widget route, {IconData? icon}) {
    // Fixed width for all buttons
    const double buttonWidth = 220;
    const double buttonHeight = 48;
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey[700]!,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 18, 18, 18), // Almost black
            side: BorderSide(color: conv.infernoColormap(0.7), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => route));
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 12),
                    child: Icon(icon, color: Colors.grey[400], size: 24),
                  ),
                ] else ...[
                  const SizedBox(width: 56), // Reserve space for icon alignment
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18, 
                      //fontFamily: GoogleFonts.raleway().fontFamily,
                      color: Colors.grey[400]!, 
                      fontWeight: FontWeight.w300, 
                      letterSpacing: 2
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(BuildContext context, IconData iconData, Widget route) {
    return IconButton(
      icon: Icon(iconData),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => route),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 32),
              _title(),
              const SizedBox(height: 36),
              _pageButton(context, "Record audio", AudioPage(), icon: Icons.mic),
              const SizedBox(height: 12),
              _pageButton(context, "Import audio", ImportPage(), icon: Icons.file_upload),
              const SizedBox(height: 12),
              _pageButton(context, "Archive", ArchivePage(), icon: Icons.archive), // folder, archive
              const SizedBox(height: 12),
              _pageButton(context, "Frontend", LoadAssets(), icon: Icons.music_note),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
