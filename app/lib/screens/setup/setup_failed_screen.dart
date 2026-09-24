import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'setup_session.dart';
import 'wifi_screen.dart';

enum FailureReason { wifi, bluetooth, cloud }

class SetupFailedScreen extends StatelessWidget {
  const SetupFailedScreen({super.key, required this.session, required this.reason});
  final SetupSession session;
  final FailureReason reason;

  @override
  Widget build(BuildContext context) {
    final (title, body, tips) = switch (reason) {
      FailureReason.wifi => (
          'Couldn’t join ${session.ssid}',
          'The purifier couldn’t connect to this network. It’s still in setup mode, so you can try again right away.',
          [
            'Password is case-sensitive — check capitals and spaces.',
            'The network must be 2.4 GHz. Some routers merge both bands under one name.',
            'Move the purifier closer to your router.',
          ],
        ),
      FailureReason.bluetooth => (
          'Lost connection to the purifier',
          'Bluetooth dropped during setup.',
          [
            'Keep your phone within 2 m of the purifier.',
            'Hold the purifier’s Wi-Fi button for 5 s until the light pulses blue, then try again.',
          ],
        ),
      FailureReason.cloud => (
          'Purifier can’t reach the internet',
          'It joined ${session.ssid} but hasn’t reached our server within 90 seconds.',
          [
            'Check that this Wi-Fi network has internet access.',
            'Some office or hotel networks block devices. Try a home network or phone hotspot.',
          ],
        ),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close setup', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ScreenBody(
        bottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => WifiScreen(session: session)),
            ),
            child: Text(reason == FailureReason.wifi ? 'Re-enter password' : 'Try again'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              session.ssid = '';
              session.password = '';
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WifiScreen(session: session)));
            },
            child: const Text('Choose another network'),
          ),
        ]),
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.badBg, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.error_outline, size: 32, color: AppColors.bad),
          ),
          const SizedBox(height: 14),
          Heading(title, subtitle: body),
          const SizedBox(height: 24),
          CardBox(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CHECK THESE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.muted)),
              const SizedBox(height: 12),
              for (var i = 0; i < tips.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: i == 0 ? AppColors.bad : AppColors.muted)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tips[i], style: const TextStyle(fontSize: 15, height: 1.45))),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
