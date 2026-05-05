import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() => runApp(const EnergyGridApp());

class EnergyGridApp extends StatelessWidget {
  const EnergyGridApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF050505)),
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
  
  // App State
  int _tabIndex = 0;
  List<double> wattsHistory = [];
  double currentLag = 0.002;
  double totalEnergyUsed = 0.0;
  double electricityRate = 0.15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. BOTTOM NAVIGATION BAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white24,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Live Grid'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = jsonDecode(snapshot.data);
          
          // Data Extraction
          final List<double> vPoints = List<double>.from(data['v_wave']);
          final List<double> iPoints = List<double>.from(data['i_wave']).map((x) => x * 15).toList();
          double displayV = (data['v_steady'] ?? 0.0).toDouble();
          double displayI = (data['i_steady'] ?? 0.0).toDouble();
          double displayW = (data['watts'] ?? 0.0).toDouble().clamp(0.0, 5000.0);
          double displayPF = (data['power_factor'] ?? 0.0).toDouble().abs();
          double phaseAngle = (data['phase_angle'] ?? 0.0).toDouble();

          // Financial Calculation (50ms slices)
          totalEnergyUsed += (displayW / 1000) * (0.05 / 3600);
          wattsHistory.add(displayW);
          if (wattsHistory.length > 100) wattsHistory.removeAt(0);

          // SWITCHING VIEWS
          return _tabIndex == 0 
            ? _buildLiveView(vPoints, iPoints, phaseAngle, displayV, displayI, displayW, displayPF)
            : _buildAnalyticsView(displayW, displayPF);
        },
      ),
    );
  }

  // --- VIEW 1: LIVE GRID (Physics Focused) ---
  Widget _buildLiveView(List<double> v, List<double> i, double angle, double vS, double iS, double wS, double pfS) {
    return Column(
      children: [
        const SizedBox(height: 50),
        _buildStatusHeader(pfS),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SizedBox(width: 100, child: CustomPaint(painter: PhasorPainter(angle))),
                const SizedBox(width: 20),
                Expanded(child: CustomPaint(painter: WavePainter(v, i))),
              ],
            ),
          ),
        ),
        _buildSlider(),
        _buildMetricsDock(vS, iS, wS, pfS),
      ],
    );
  }

  // --- VIEW 2: ANALYTICS (Business Focused) ---
  Widget _buildAnalyticsView(double watts, double pf) {
    return Column(
      children: [
        const SizedBox(height: 60),
        const Text("FINANCIAL SUMMARY", style: TextStyle(letterSpacing: 2, color: Colors.white38)),
        _buildCostCard(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text("POWER TREND (100 SAMPLES)", style: TextStyle(fontSize: 10, color: Colors.white24)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: CustomPaint(painter: TrendPainter(wattsHistory)),
          ),
        ),
        _buildEfficiencyInsight(pf),
      ],
    );
  }

  // --- REUSABLE UI COMPONENTS ---

  Widget _buildStatusHeader(double pf) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(pf < 0.6 ? "🚨 CRITICAL PHASE SHIFT" : "✅ SYSTEM STABLE",
          style: TextStyle(color: pf < 0.6 ? Colors.red : Colors.greenAccent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSlider() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Slider(
        value: currentLag, min: 0.002, max: 0.010,
        onChanged: (val) {
          setState(() => currentLag = val);
          channel.sink.add(val.toString());
        },
      ),
    );
  }

  Widget _buildCostCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ENERGY USED", style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text("${totalEnergyUsed.toStringAsFixed(4)} kWh", style: const TextStyle(fontSize: 18)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("TOTAL COST", style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text("\$${(totalEnergyUsed * electricityRate).toStringAsFixed(3)}", 
                 style: const TextStyle(fontSize: 24, color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildMetricsDock(double v, double i, double w, double pf) {
    return Container(
      padding: const EdgeInsets.all(25),
      color: Colors.black,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _metric("VOLTS", v.toStringAsFixed(1)),
        _metric("AMPS", i.toStringAsFixed(1)),
        _metric("WATTS", w.toStringAsFixed(0)),
        _metric("PF", pf.toStringAsFixed(2)),
      ]),
    );
  }

  Widget _metric(String label, String val) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9)),
    Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);

  Widget _buildEfficiencyInsight(double pf) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Text(
        pf < 0.8 ? "Tip: Low Power Factor detected. Adding capacitors could reduce energy waste." : "System is running at peak efficiency.",
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12),
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

class PhasorPainter extends CustomPainter {
  final double angle; // in radians
  PhasorPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;
    final paintBase = Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = 1;

    // 1. Draw Background Circle and Crosshairs
    canvas.drawCircle(center, radius, paintBase);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paintBase);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paintBase);

    // 2. Voltage Vector (Fixed at 0 degrees / 12 o'clock)
    final vPaint = Paint()..color = Colors.greenAccent..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx, center.dy - radius), vPaint);

    // 3. Current Vector (Rotates based on angle)
    // In Flutter, 0 radians is 3 o'clock, so we subtract pi/2 to start at 12 o'clock
    final double adjustedAngle = angle - (3.14159 / 2); 
    final iPaint = Paint()..color = Colors.blueAccent..strokeWidth = 3..strokeCap = StrokeCap.round;
    
    final iEndPoint = Offset(
      center.dx + (radius * 0.8) * math.cos(adjustedAngle),
      center.dy + (radius * 0.8) * math.sin(adjustedAngle),
    );
    canvas.drawLine(center, iEndPoint, iPaint);
    
    // Add arrow head for Current
    canvas.drawCircle(iEndPoint, 4, iPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}