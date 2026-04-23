# ActiveBeat

**A Real-Time Embedded Motion Classification and BLE-Connected Music System**

---

## 📌 Overview

**ActiveBeat** is an end-to-end embedded AI system that connects **on-device motion recognition** with **adaptive music playback**.

The system uses an Arduino Nano 33 BLE Sense to classify user activity (walking, running, resting) in real time using a TinyML model. The predicted activity is transmitted via Bluetooth Low Energy (BLE) to a Flutter mobile application, which automatically switches music playlists accordingly.

This project explores how **embedded machine learning can be deployed beyond offline classification**, enabling real-time interaction and user-facing applications.

---

## 🎯 Key Features

* 📡 **On-device inference (TinyML)**
  Motion classification runs directly on Arduino (no cloud)

* 📊 **IMU-based activity recognition**
  Uses accelerometer data for:

  * Walking
  * Running
  * Resting

* 🔗 **BLE real-time communication**
  Activity state is transmitted via notify characteristic

* 🎧 **Adaptive music system (Flutter app)**
  Automatically switches playlists based on activity

* ⚙️ **System stability mechanisms**

  * Duplicate filtering
  * State change detection
  * Debounce (3s) to avoid rapid switching

---

## 🧱 System Architecture

```text
IMU (Arduino Nano 33 BLE Sense)
        ↓
TinyML Model (Edge Impulse)
        ↓
Real-time Activity Classification
        ↓
BLE Transmission (SportMusicNano)
        ↓
Flutter App (Android)
        ↓
Adaptive Music Playback
```

---

## 📁 Repository Structure

```text
.
├── arduino/
│   ├── inference/
│   └── data_collection/
│
├── flutter_app/
│   ├── lib/
│   └── assets/audio/
│
├── dataset/
│   ├── walking/
│   ├── running/
│   └── resting/
│
└── report/
```

👉 Quick links:

* 🔧 Arduino code:
  [https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/arduino](https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/arduino)

* 📱 Flutter App:
  [https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/flutter_app](https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/flutter_app)

* 📊 Dataset:
  [https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/dataset](https://github.com/CynthiaZHANGovo/Deep-Learning-for-Sensor-Networks/tree/main/dataset)

---

## 📊 Data Collection

The dataset was collected using the **Arduino Nano 33 BLE Sense** accelerometer.

### Workflow

```text
Arduino (IMU sampling)
        ↓ USB Serial
Python script
        ↓
Automatic CSV generation
        ↓
Upload to Edge Impulse
```

A Python-based data collection tool was used to simplify the process and improve efficiency compared to manual logging. This tool handled:

* Real-time serial data capture
* Automatic CSV file generation
* Basic formatting and structuring for Edge Impulse

### Dataset Details

* Classes:

  * walking
  * running
  * resting

* Sampling rate:

  * ~20–50 Hz

* Recording strategy:

  * Each file contains a single activity
  * Device position kept consistent
  * Each class recorded in multiple sessions

### Preprocessing

Initial preprocessing was applied during data collection:

* Consistent file structure (per class)
* Removal of corrupted samples
* Basic formatting for direct upload to Edge Impulse

The dataset was then segmented and processed within Edge Impulse for feature extraction and training.

---

## 🤖 Model

* Platform: Edge Impulse
* Type: Time-series motion classification
* Input: Accelerometer window (x, y, z)
* Output:

  * walking
  * running
  * resting

### Design Considerations

* Lightweight model for embedded deployment
* Real-time inference capability
* Focus on usability, not only accuracy

The trained model was exported as an Arduino library and deployed directly on the device for **on-device inference**.

---

## 📱 Mobile Application

The Flutter Android application is responsible for:

* BLE scanning and connection
* Subscribing to activity notifications
* Decoding UTF-8 state messages
* Switching playlists based on activity

### Behaviour Design

To improve real-world usability:

* Repeated identical states are ignored
* Music changes only when activity changes
* A 3-second debounce prevents rapid switching

This ensures smoother interaction compared to directly using raw model output.

---

## 🚀 Results

* Real-time motion classification running on Arduino
* Stable BLE communication between device and app
* Successful adaptive playlist switching


---

## 🔮 Future Work

* Expand activity classes (e.g. cycling, stairs)
* Multi-scenarios dataset collection
* Improve robustness under varied conditions

---

## 👩‍💻 Author

**Xinyi Zhang**
