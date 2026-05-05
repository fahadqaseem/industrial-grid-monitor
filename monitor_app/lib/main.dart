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
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
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
  
  // Storage for the Power Trend Chart
  List<double> wattsHistory = [];
  double currentLag = 0.002; // Local state for the slider

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("GRID MONITOR V2", style: TextStyle(fontSize: 14, color: Colors.white24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.orangeAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen(data: wattsHistory)),
              );
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final data = jsonDecode(snapshot.data);
            
            // 1. WAVE DATA
            final List<double> vPoints = List<double>.from(data['v_wave']);
            final List<double> iPoints = List<double>.from(data['i_wave']).map((x) => x * 15).toList();

            // 2. METRICS & ALERTS
            double displayV = (data['v_steady'] ?? 0.0).toDouble();
            double displayI = (data['i_steady'] ?? 0.0).toDouble();
            double displayW = (data['watts'] ?? 0.0).toDouble().clamp(0.0, 5000.0);
            double displayPF = (data['power_factor'] ?? 0.0).toDouble().abs();

            // Update history for the trend line
            wattsHistory.add(displayW);
            if (wattsHistory.length > 100) wattsHistory.removeAt(0);

            return Column(
              children: [
                // REFINED STATUS ALERT
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: displayPF < 0.5 ? Colors.red.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: displayPF < 0.5 ? Colors.redAccent : (displayPF < 0.8 ? Colors.orange : Colors.greenAccent.withOpacity(0.3)),
                    ),
                  ),
                  child: Text(
                    displayPF < 0.5 ? "🚨 CRITICAL: LOW POWER FACTOR" : 
                    displayPF < 0.8 ? "⚠️ WARNING: INEFFICIENT LOAD" : "✅ GRID STABLE",
                    style: TextStyle(
                      color: displayPF < 0.5 ? Colors.redAccent : (displayPF < 0.8 ? Colors.orange : Colors.greenAccent),
                      fontWeight: FontWeight.bold, fontSize: 11,
                    ),
                  ),
                ),

                // OSCILLOSCOPE
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CustomPaint(
                      painter: WavePainter(vPoints, iPoints),
                      child: Container(),
                    ),
                  ),
                ),

                // INTERACTIVE SLIDER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("LOAD MAGNITUDE (PHASE LAG)", style: TextStyle(fontSize: 9, color: Colors.white54)),
                          Text("${(currentLag * 1000).toStringAsFixed(1)} ms", style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
                        ],
                      ),
                      Slider(
                        value: currentLag,
                        min: 0.002,
                        max: 0.010,
                        activeColor: currentLag > 0.006 ? Colors.orangeAccent : Colors.blueAccent,
                        onChanged: (value) {
                          setState(() => currentLag = value);
                          channel.sink.add(value.toString()); // Send to Python
                        },
                      ),
                    ],
                  ),
                ),

                // MINI TREND LINE
                SizedBox(
                  height: 30,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: CustomPaint(painter: TrendPainter(wattsHistory)),
                  ),
                ),

                const SizedBox(height: 20),
                
                // DATA READOUT
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      metric("VOLTAGE", "${displayV.toStringAsFixed(1)}V", Colors.greenAccent),
                      metric("CURRENT", "${displayI.toStringAsFixed(1)}A", Colors.blueAccent),
                      metric("POWER", "${displayW.toStringAsFixed(0)}W", displayPF < 0.7 ? Colors.orangeAccent : Colors.white),
                      metric("P. FACTOR", displayPF.toStringAsFixed(2), displayPF < 0.5 ? Colors.redAccent : Colors.purpleAccent),
                    ],
                  ),
                )
              ],
            );
          }
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        },
      ),
    );
  }

  Widget metric(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
      ],
    );
  }
}

// --- FULL HISTORY SCREEN ---
class HistoryScreen extends StatelessWidget {
  final List<double> data;
  const HistoryScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("100-POINT POWER LOG")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("WATTS OVER TIME", style: TextStyle(color: Colors.orangeAccent, letterSpacing: 2)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              height: 300,
              child: CustomPaint(painter: TrendPainter(data)),
            ),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("This chart shows the real-time efficiency drops as you adjust the motor load slider.", 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAINTERS ---

class WavePainter extends CustomPainter {
  final List<double> vPoints;
  final List<double> iPoints;
  WavePainter(this.vPoints, this.iPoints);

  @override
  void paint(Canvas canvas, Size size) {
    double midY = size.height / 2;
    double spacing = size.width / (vPoints.length - 1); 
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    
    // Draw Grid Lines
    for(var i=1; i<4; i++) {
       double y = (size.height/4) * i;
       canvas.drawLine(Offset(0, y), Offset(size.width, y), bgPaint);
    }

    if (vPoints.isEmpty) return;

    final vPath = Path()..moveTo(0, midY - (vPoints[0] / 2));
    final iPath = Path()..moveTo(0, midY - iPoints[0]);

    for (int i = 0; i < vPoints.length; i++) {
      vPath.lineTo(i * spacing, midY - (vPoints[i] / 2));
      iPath.lineTo(i * spacing, midY - iPoints[i]);
    }

    canvas.drawPath(vPath, Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawPath(iPath, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TrendPainter extends CustomPainter {
  final List<double> data;
  TrendPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()..color = Colors.orangeAccent..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path();
    double spacing = size.width / 99;
    double maxW = 2500.0; 
    
    path.moveTo(0, size.height - (data[0] / maxW * size.height));
    for (int i = 1; i < data.length; i++) {
      path.lineTo(i * spacing, size.height - (data[i] / maxW * size.height));
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}