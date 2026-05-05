import asyncio
import websockets
import json
import math
import time

# Add this variable at the very top of your file (below the imports)
motor_active = False


async def simulate_grid(websocket):
    global motor_active
    start_time = time.time()

    # This task listens for the Flutter button click
    async def listen_for_commands():
        global motor_active
        async for message in websocket:
            if message == "TOGGLE_MOTOR":
                motor_active = not motor_active
                print(f"Motor state changed: {motor_active}")

    # Start listening in the background
    asyncio.create_task(listen_for_commands())

    # Replace your while True loop logic in main.py
    while True:
        elapsed = time.time() - start_time
        phase_lag = 0.006 if motor_active else 0.002

        # Generate a full snapshot (2 cycles)
        v_wave = []
        i_wave = []
        v_wave = []
        i_wave = []
        resolution = 200  # More points = smoother curves
        for step in range(resolution):
            # t still covers 2 full cycles (0.04s)
            t = step * (0.04 / resolution)
            v_val = 230 * math.sin(2 * math.pi * 50 * t)
            i_val = 10 * math.sin(2 * math.pi * 50 * (t - phase_lag))
            v_wave.append(v_val)
            i_wave.append(i_val)

        # Steady values (calculated once per frame)
        v_rms = 230 / math.sqrt(2)
        i_rms = 10 / math.sqrt(2)
        pf = math.cos(2 * math.pi * 50 * phase_lag)

        payload = {
            "v_wave": v_wave,
            "i_wave": i_wave,
            "v_steady": v_rms,
            "i_steady": i_rms,
            "watts": v_rms * i_rms * pf,
            "power_factor": pf,
            "motor_on": motor_active
        }

        await websocket.send(json.dumps(payload))
        await asyncio.sleep(0.05)  # Refresh the whole screen 20 times a second

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

        # Inside your while True loop in main.py:

