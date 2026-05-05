import asyncio
import websockets
import json
import math
import time


async def simulate_grid(websocket):
    start_time = time.time()
    while True:
        elapsed = time.time() - start_time

        # 1. GENERATE PHYSICS DATA
        frequency = 50
        # Voltage (230V Peak)
        v_instant = 230 * math.sin(2 * math.pi * frequency * elapsed)

        # Current (10A Peak) with a 2ms lag (Simulating an Industrial Motor)
        phase_lag_seconds = 0.002
        i_instant = 10 * math.sin(2 * math.pi * frequency * (elapsed - phase_lag_seconds))

        # 2. CALCULATE "THE TRUTH" (Master Math)
        # Power Factor = cos(angular_frequency * time_delay)
        phi = 2 * math.pi * frequency * phase_lag_seconds
        pf = math.cos(phi)

        # Active Power (Watts) = V_rms * I_rms * PF
        v_rms = 230 / math.sqrt(2)
        i_rms = 10 / math.sqrt(2)
        watts = v_rms * i_rms * pf

        # 3. SEND TO FLUTTER
        payload = {
            "voltage": v_instant,
            "current": i_instant,
            "power_factor": pf,
            "watts": watts
        }

        await websocket.send(json.dumps(payload))
        await asyncio.sleep(0.02)  # 50Hz Update Rate


async def main():
    # This creates and starts the server in the modern way
    async with websockets.serve(simulate_grid, "localhost", 8765):
        print("Industrial Grid Server started on ws://localhost:8765")
        await asyncio.Future()  # This keeps the server running forever

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Server stopped by user")