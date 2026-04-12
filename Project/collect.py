import csv
import time
from pathlib import Path

import serial

# ===== 固定参数 =====
PORT = "COM13"
BAUD = 115200
DURATION = 20

BASE_DIR = Path("dataset")

KEY_TO_LABEL = {
    "w": "walking",
    "r": "running",
    "s": "resting",
}


def get_next_filename(label):
    label_dir = BASE_DIR / label
    label_dir.mkdir(parents=True, exist_ok=True)

    existing = sorted(label_dir.glob(f"{label}_*.csv"))

    max_index = 0
    for f in existing:
        num = f.stem.split("_")[-1]
        if num.isdigit():
            max_index = max(max_index, int(num))

    return label_dir / f"{label}_{max_index+1:03d}.csv"


def collect(ser, label):
    filename = get_next_filename(label)

    print(f"\nPrepare for {label}...")
    for i in range(3, 0, -1):
        print(f"Starting in {i}...")
        time.sleep(1)

    print("GO!")

    start = time.time()

    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", "ax", "ay", "az", "label"])

        while time.time() - start < DURATION:
            line = ser.readline().decode(errors="ignore").strip()

            if not line:
                continue

            parts = line.split(",")
            if len(parts) != 3:
                continue

            try:
                ax, ay, az = map(float, parts)
            except:
                continue

            ts = time.time() - start
            writer.writerow([f"{ts:.3f}", ax, ay, az, label])

    print(f"Done → saved: {filename}")


def main():
    print(f"Using port: {PORT}")

    ser = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(2)

    print("\nControls:")
    print("w = walking")
    print("r = running")
    print("s = resting")
    print("q = quit")

    while True:
        key = input("\nPress key: ").strip().lower()

        if key == "q":
            print("Bye!")
            break

        if key in KEY_TO_LABEL:
            collect(ser, KEY_TO_LABEL[key])
        else:
            print("Invalid key")

    ser.close()


if __name__ == "__main__":
    main()