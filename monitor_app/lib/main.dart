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
  final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));
  List<double> vHistory = [];
  List<double> iHistory = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), 
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = jsonDecode(snapshot.data);
            
            // 1. UPDATE BUFFERS
            vHistory.add(data['voltage']);
            iHistory.add(data['current'] * 15); // DISPLAY MATH (Scaling for visibility)

            if (vHistory.length > 100) {
              vHistory.removeAt(0);
              iHistory.removeAt(0);
            }

            return Column(
              children: [
                const SizedBox(height: 60),
                const Text("LIVE POWER ANALYSIS", 
                  style: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 10)),
                
                // 2. OSCILLOSCOPE AREA
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomPaint(
                      painter: WavePainter(vHistory, iHistory),
                      child: Container(),
                    ),
                  ),
                ),
                
                // 3. POWER SYSTEM LAYOUT (The Bottom Dashboard)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: // REPLACE THE Row INSIDE SECTION 3 WITH THIS:
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          metric("VOLTAGE", "${data['voltage'].toStringAsFixed(1)}V", Colors.greenAccent),
                          metric("CURRENT", "${data['current'].toStringAsFixed(2)}A", Colors.blueAccent),
                          // Pre-calculated in Python for accuracy
                          metric("POWER", "${(data['watts'] ?? 0).toStringAsFixed(0)}W", Colors.orangeAccent),
                          // Shows how well Voltage and Current are in sync
                          metric("P. FACTOR", "${(data['power_factor'] ?? 0).toStringAsFixed(2)}", Colors.purpleAccent),
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
        const SizedBox(height: 8),
        Text(val, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
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
    if (vPoints.isEmpty) return;

    final vPath = Path()..moveTo(0, midY - (vPoints[0] / 2));
    final iPath = Path()..moveTo(0, midY - iPoints[0]);

    for (int i = 0; i < vPoints.length; i++) {
      vPath.lineTo(i * spacing, midY - (vPoints[i] / 2));
      iPath.lineTo(i * spacing, midY - iPoints[i]);
    }

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), Paint()..color = Colors.white10);
    canvas.drawPath(vPath, Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawPath(iPath, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}