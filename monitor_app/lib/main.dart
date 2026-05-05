import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(const EnergyGridApp());

class EnergyGridApp extends StatelessWidget {
  const EnergyGridApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // Connection to the Python "Digital Twin"
  final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));
  
  // Buffers for our waveforms (Memory for the oscilloscope)
  List<double> vHistory = [];
  List<double> iHistory = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // OLED Black
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = jsonDecode(snapshot.data);
            
            // 1. Logic: Update buffers with latest data
            vHistory.add(data['voltage']);
            iHistory.add(data['current'] * 15); // Scaled up so current is visible

            // 2. Sliding Window: Keep only the last 100 data points
            if (vHistory.length > 100) {
              vHistory.removeAt(0);
              iHistory.removeAt(0);
            }

            return Column(
              children: [
                const SizedBox(height: 60),
                const Text("INDUSTRIAL GRID MONITOR", 
                  style: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 10)),
                
                // 3. Visualization: The Dual-Wave Oscilloscope
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: CustomPaint(
                      painter: WavePainter(vHistory, iHistory),
                      child: Container(),
                    ),
                  ),
                ),
                
                // 4. Digital Readout: Professional Metrics
                Container(
                  padding: const EdgeInsets.all(40),
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      metric("VOLTAGE", "${data['voltage'].toStringAsFixed(1)}V", Colors.greenAccent),
                      metric("CURRENT", "${data['current'].toStringAsFixed(2)}A", Colors.blueAccent),
                    ],
                  ),
                )
              ],
            );
          }
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        },
      ),
    );
  }

  Widget metric(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        Text(val, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w200, fontFamily: 'Courier')),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final List<double> vPoints;
  final List<double> iPoints;
  WavePainter(this.vPoints, this.iPoints);

  @override
  void paint(Canvas canvas, Size size) {
    double midY = size.height / 2;
    double spacing = size.width / 100;

    // Draw Zero-Line reference
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), Paint()..color = Colors.white10);

    if (vPoints.isEmpty) return;

    final vPath = Path()..moveTo(0, midY - (vPoints[0] / 2));
    final iPath = Path()..moveTo(0, midY - iPoints[0]);

    for (int i = 0; i < vPoints.length; i++) {
      // Voltage scaled to half-height
      vPath.lineTo(i * spacing, midY - (vPoints[i] / 2));
      // Current drawn at 1:1 scale with its internal multiplier
      iPath.lineTo(i * spacing, midY - iPoints[i]);
    }

    // Paint Voltage (Green)
    canvas.drawPath(vPath, Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 2);
    // Paint Current (Blue)
    canvas.drawPath(iPath, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}