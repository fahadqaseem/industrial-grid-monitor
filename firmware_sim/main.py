import asyncio
import websockets
import json
import numpy as np
import time

# --- PHYSICS CONSTANTS ---
GRID_FREQUENCY = 50.0  # Hz
VOLTAGE_PEAK = 230.0  # Volts
AMPERAGE_PEAK = 15.0  # Amps
PHASE_LAG = 0.002  # 2ms lag (Inductive load simulation)


async def energy_stream(websocket):
    print(f"Connection established with: {websocket.remote_address}")
    start_time = time.time()

    try:
        while True:
            # Current time relative to start
            t = time.time() - start_time

            # V(t) = V_peak * sin(2 * pi * f * t)
            voltage = VOLTAGE_PEAK * np.sin(2 * np.pi * GRID_FREQUENCY * t)

            # I(t) = I_peak * sin(2 * pi * f * (t - lag))
            current = AMPERAGE_PEAK * np.sin(2 * np.pi * GRID_FREQUENCY * (t - PHASE_LAG))

            # Calculate Instantaneous Power (Watts)
            power = voltage * current

            # Package data for the Flutter Dashboard
            payload = {
                "voltage": round(voltage, 4),
                "current": round(current, 4),
                "power": round(power, 4),
                "timestamp": t
            }

            await websocket.send(json.dumps(payload))

            # 16.67ms sleep = roughly 60 updates per second
            await asyncio.sleep(1 / 60)

    except websockets.exceptions.ConnectionClosed:
        print("Dashboard disconnected.")


async def main():
    print("--- ENERGY GRID MONITOR: VIRTUAL SENSOR ---")
    print("Server starting at ws://localhost:8765")
    async with websockets.serve(energy_stream, "localhost", 8765):
        await asyncio.Future()  # Keeps the server running indefinitely


if __name__ == "__main__":
    asyncio.run(main())