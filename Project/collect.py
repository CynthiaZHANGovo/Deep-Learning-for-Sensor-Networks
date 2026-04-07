import csv
import time
import serial
from serial.tools import list_ports

# 自动找 Arduino 端口
ports = list(list_ports.comports())
for i, p in enumerate(ports):
    print(f"{i}: {p.device} - {p.description}")

idx = int(input("Select port number: "))
port = ports[idx].device

label = input("Enter label (walking/running/resting): ").strip()
duration = int(input("Duration (seconds): ").strip())

ser = serial.Serial(port, 115200, timeout=1)
time.sleep(2)  # 等串口稳定

filename = f"{label}_{int(time.time())}.csv"
start = time.time()

with open(filename, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["timestamp", "ax", "ay", "az", "label"])

    print(f"Collecting {label} for {duration}s on {port} ...")

    while time.time() - start < duration:
        line = ser.readline().decode(errors="ignore").strip()
        if not line:
            continue

        parts = line.split(",")
        if len(parts) != 3:
            continue

        try:
            ax, ay, az = map(float, parts)
        except ValueError:
            continue

        ts = time.time() - start
        writer.writerow([ts, ax, ay, az, label])
        print(f"{ts:.2f}, {ax}, {ay}, {az}")

ser.close()
print(f"Saved to {filename}")