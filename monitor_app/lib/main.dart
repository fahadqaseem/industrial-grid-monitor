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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = jsonDecode(snapshot.data);
            
            // 1. CREATE LISTS LOCALLY (No setState needed!)
            // We pull the full arrays directly from the snapshot
            final List<double> vPoints = List<double>.from(data['v_wave']);
            final List<double> iPoints = List<double>.from(data['i_wave'])
                .map((x) => x * 15)
                .toList();

            double displayV = data['v_steady'] ?? 0.0;
            double displayI = data['i_steady'] ?? 0.0;
            double displayW = data['watts'] ?? 0.0;
            double displayPF = data['power_factor'] ?? 0.0;
            bool isMotorOn = data['motor_on'] ?? false;

            return Column(
              children: [
                const SizedBox(height: 60),
                const Text("STATIONARY WAVE ANALYSIS", 
                  style: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 10)),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: CustomPaint(
                      // Pass the local lists directly to the painter
                      painter: WavePainter(vPoints, iPoints),
                      child: Container(),
                    ),
                  ),
                ),

                // 3. INTERACTIVE CONTROL
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => channel.sink.add("TOGGLE_MOTOR"),
                    icon: Icon(Icons.settings_input_component, 
                        color: isMotorOn ? Colors.orangeAccent : Colors.greenAccent),
                    label: Text(isMotorOn ? "STOP INDUCTIVE MOTOR" : "START INDUCTIVE MOTOR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      side: BorderSide(color: isMotorOn ? Colors.orange : Colors.green, width: 0.5)
                    ),
                  ),
                ),
                
                // 4. STEADY METRICS (No more flickering numbers!)
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      metric("VOLTAGE", "${displayV.toStringAsFixed(1)}V", Colors.greenAccent),
                      metric("CURRENT", "${displayI.toStringAsFixed(1)}A", Colors.blueAccent),
                      metric("POWER", "${displayW.toStringAsFixed(0)}W", Colors.orangeAccent),
                      metric("P. FACTOR", displayPF.toStringAsFixed(2), Colors.purpleAccent),
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
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9)),
        const SizedBox(height: 5),
        Text(val, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
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
    
    // CALCULATE DYNAMIC SPACING
    // This ensures that whether we send 50 points or 200, 
    // the wave always stretches across the full width of the screen.
    double spacing = size.width / (vPoints.length - 1); 

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), Paint()..color = Colors.white10);

    if (vPoints.isEmpty) return;

    final vPath = Path()..moveTo(0, midY - (vPoints[0] / 2));
    final iPath = Path()..moveTo(0, midY - iPoints[0]);

    for (int i = 0; i < vPoints.length; i++) {
      vPath.lineTo(i * spacing, midY - (vPoints[i] / 2));
      iPath.lineTo(i * spacing, midY - iPoints[i]);
    }

    // Use Anti-Aliasing for even smoother lines
    final paintV = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..isAntiAlias = true;

    final paintI = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..isAntiAlias = true;

    canvas.drawPath(vPath, paintV);
    canvas.drawPath(iPath, paintI);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}