import csv
import time
from pathlib import Path

import serial
from serial.tools import list_ports


VALID_LABELS = ["walking", "running", "resting"]
BASE_DIR = Path("dataset")


def choose_port() -> str:
    ports = list(list_ports.comports())

    if not ports:
        raise RuntimeError("No serial ports found. Please connect your Arduino and try again.")

    print("Available serial ports:")
    for i, p in enumerate(ports):
        print(f"{i}: {p.device} - {p.description}")

    while True:
        choice = input("Select port number: ").strip()
        try:
            idx = int(choice)
            if 0 <= idx < len(ports):
                return ports[idx].device
        except ValueError:
            pass
        print("Invalid selection. Please enter a valid port number.")


def choose_label() -> str:
    print(f"Available labels: {', '.join(VALID_LABELS)}")
    while True:
        label = input("Enter label: ").strip().lower()
        if label in VALID_LABELS:
            return label
        print("Invalid label. Please choose one of: walking, running, resting.")


def choose_duration() -> int:
    while True:
        value = input("Duration (seconds): ").strip()
        try:
            duration = int(value)
            if duration > 0:
                return duration
        except ValueError:
            pass
        print("Invalid duration. Please enter a positive integer.")


def get_next_filename(label: str) -> Path:
    label_dir = BASE_DIR / label
    label_dir.mkdir(parents=True, exist_ok=True)

    existing = sorted(label_dir.glob(f"{label}_*.csv"))

    max_index = 0
    for f in existing:
        stem = f.stem  # e.g. walking_003
        parts = stem.split("_")
        if len(parts) == 2 and parts[0] == label and parts[1].isdigit():
            max_index = max(max_index, int(parts[1]))

    next_index = max_index + 1
    return label_dir / f"{label}_{next_index:03d}.csv"


def main() -> None:
    port = choose_port()
    label = choose_label()
    duration = choose_duration()

    filename = get_next_filename(label)

    ser = serial.Serial(port, 115200, timeout=1)
    time.sleep(2)

    start = time.time()

    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", "ax", "ay", "az", "label"])

        print(f"Collecting '{label}' for {duration} seconds on {port} ...")
        print(f"Saving to: {filename}")

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
            writer.writerow([f"{ts:.3f}", ax, ay, az, label])
            print(f"{ts:.2f}, {ax}, {ay}, {az}")

    ser.close()
    print(f"Done. Saved to {filename}")


if __name__ == "__main__":
    main()