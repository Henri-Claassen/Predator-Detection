# Predator Detection System

An automated wildlife predator detection system using a Raspberry Pi, a USB webcam, and YOLOv8 object detection. Detections are logged to a MySQL database.

## How It Works

1. `stream_server.py` runs on a Raspberry Pi and serves the connected webcam as an MJPEG stream
2. `detector.py` reads the stream and runs YOLOv8 inference on each frame
3. When a predator is detected, the result is logged to a MySQL database via `database_connect.py`

## File Overview

| File | Runs On | Purpose |
|---|---|---|
| `detector.py` | Laptop / PC | YOLOv8 inference on the video stream |
| `stream_server.py` | Raspberry Pi | Serves USB webcam as MJPEG stream |
| `database_connect.py` | Laptop / PC | MySQL logging for detections |
| `yolov8s-oiv7.pt` | Laptop / PC | YOLOv8 model weights (Open Images V7) |

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/Henri-Claassen/Predator-Detection.git
cd Predator-Detection
```

### 2. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure environment variables

The `.env` file is not included in the repo. Create it yourself in the project root:

```bash
touch .env
```

Then open it and add your database credentials:

```
DB_HOST=your_database_host
DB_PORT=3306
DB_USER=your_user
DB_PASSWORD=your_password
DB_NAME=your_database_name
```

### 4. Set up the camera stream on the Pi

```bash
# On your Raspberry Pi
pip install flask opencv-python
python stream_server.py
# Note the stream URL it prints, e.g. http://INSERT_IP_HERE:5000/stream
```

For cross-network access (e.g. running the detector from a different network), use ngrok:

```bash
ngrok http 5000
# Use the printed https URL as your stream URL in detector.py
```

### 5. Run the detector

```bash
python detector.py
```

## Requirements

- Python 3.9+
- MySQL database
- Raspberry Pi with a USB webcam
