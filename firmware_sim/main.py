import asyncio
import websockets
import json
import math
import time

# Global variable to track the phase lag (controlled by the Flutter slider)
# Default 0.002 represents a high-efficiency load
motor_lag_target = 0.002


async def simulate_grid(websocket):
    global motor_lag_target
    start_time = time.time()

    # Listen for slider data or commands from Flutter
    async def listen_for_commands():
        global motor_lag_target
        async for message in websocket:
            try:
                # If Flutter sends "TOGGLE_MOTOR", we jump between two states
                if message == "TOGGLE_MOTOR":
                    motor_lag_target = 0.006 if motor_lag_target == 0.002 else 0.002
                else:
                    # Otherwise, treat the message as a raw float from the Slider
                    val = float(message)
                    # Safety clamp: 2ms to 10ms lag
                    motor_lag_target = max(0.002, min(0.010, val))
            except ValueError:
                pass

    # Start the listener in the background
    asyncio.create_task(listen_for_commands())

    while True:
        # 1. PHYSICS CONSTANTS
        v_peak = 230
        i_peak = 10
        phase_lag = motor_lag_target

        # 2. GENERATE HIGH-RES SNAPSHOT (200 points for smooth curves)
        v_wave = []
        i_wave = []
        resolution = 200
        for step in range(resolution):
            # t covers 2 full cycles at 50Hz (0.04 seconds)
            t = step * (0.04 / resolution)
            v_val = v_peak * math.sin(2 * math.pi * 50 * t)
            i_val = i_peak * math.sin(2 * math.pi * 50 * (t - phase_lag))
            v_wave.append(v_val)
            i_wave.append(i_val)

        # 3. STEADY CALCULATIONS (RMS and Power Factor)
        # RMS = Peak / sqrt(2)
        v_rms = v_peak * 0.707
        i_rms = i_peak * 0.707

        # Calculate Power Factor: cos(phi)
        # At 50Hz, 0.02s = 360 degrees (2*pi radians)
        angle_rad = (phase_lag / 0.02) * (2 * math.pi)
        pf = abs(math.cos(angle_rad))

        # Calculate Real Power (Watts)
        watts = v_rms * i_rms * pf

        # 4. DATA PAYLOAD
        payload = {
            "v_wave": v_wave,
            "i_wave": i_wave,
            "v_steady": v_rms,
            "i_steady": i_rms,
            "watts": watts,
            "power_factor": pf,
            "lag_value": phase_lag,
            "motor_on": motor_lag_target > 0.003  # True if load is significant
        }

        try:
            await websocket.send(json.dumps(payload))
        except websockets.ConnectionClosed:
            break

        # Refresh rate: 20fps for a stable UI
        await asyncio.sleep(0.05)


async def main():
    async with websockets.serve(simulate_grid, "localhost", 8765):
        print("Variable Load Grid Server started on ws://localhost:8765")
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nServer stopped by user.")