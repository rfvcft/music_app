import 'package:flutter/material.dart';
import 'package:music_app/core/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Note Label Display',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 16),
            ToggleButtons(
              isSelected: [
                AppSettings.instance.showPitchClasses,
                !AppSettings.instance.showPitchClasses
              ],
              onPressed: (int index) {
                setState(() {
                  AppSettings.instance.showPitchClasses = (index == 0);
                });
              },
              borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.green,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Pitch Classes'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Scale Degrees'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
