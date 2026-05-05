import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(const EnergyGridApp());
}

class EnergyGridApp extends StatelessWidget {
  const EnergyGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // OLED Black
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
  // Connect to the port your PyCharm script is broadcasting on
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8765'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          if (snapshot.hasData) {
            // Decode the JSON from Python
            final data = jsonDecode(snapshot.data);
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("LIVE TELEMETRY", 
                    style: TextStyle(letterSpacing: 4, color: Colors.grey)),
                  const SizedBox(height: 20),
                  
                  // Displaying the sine wave values
                  telemetryRow("VOLTAGE", "${data['voltage']} V", Colors.greenAccent),
                  telemetryRow("CURRENT", "${data['current']} A", Colors.blueAccent),
                  telemetryRow("POWER", "${data['power']} W", Colors.orangeAccent),
                  
                  const SizedBox(height: 40),
                  const Text("SYSTEM STATUS: OPTIMAL", 
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget telemetryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          Text(value, style: TextStyle(fontSize: 42, color: color, fontWeight: FontWeight.w200, fontFamily: 'Courier')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}