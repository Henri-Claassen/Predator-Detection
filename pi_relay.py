"""
pi_relay.py  —  Run this on your Raspberry Pi

Fetches the MJPEG stream from the ESP32-CAM (local WiFi)
and re-serves it on port 5000 so detector.py can reach it
over the NetBird VPN.

SETUP:
  1. SSH into your Pi
  2. Install deps:   pip install flask opencv-python
  3. Set ESP32_STREAM_URL below to your ESP32-CAM's local IP
  4. Run:            python pi_relay.py

STREAM URLS (replace 100.64.0.2 with your Pi's NetBird IP):
  Browser preview:  http://100.64.0.2:5000/
  detector.py URL:  http://100.64.0.2:5000/stream
"""

from flask import Flask, Response
import cv2
import socket

# -------------------------------------------------------
# SET THIS to your ESP32-CAM's local IP address
# Find it in Arduino Serial Monitor after flashing
# -------------------------------------------------------
ESP32_STREAM_URL = "http://192.168.1.100:81/stream"

PORT = 5000

# -------------------------------------------------------
# Connect to ESP32-CAM stream
# -------------------------------------------------------
print(f"Connecting to ESP32-CAM at: {ESP32_STREAM_URL}")
cap = cv2.VideoCapture(ESP32_STREAM_URL)

if not cap.isOpened():
    print("ERROR: Could not connect to ESP32-CAM stream.")
    print(f"  Check that {ESP32_STREAM_URL} is reachable from this Pi.")
    print("  Try opening that URL in a browser on this Pi first.")
    exit(1)

print("Connected to ESP32-CAM stream.")

app = Flask(__name__)


def generate():
    while True:
        ok, frame = cap.read()
        if not ok:
            print("Warning: lost frame from ESP32-CAM, retrying...")
            cap.open(ESP32_STREAM_URL)
            continue

        _, buf = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        yield (
            b'--frame\r\n'
            b'Content-Type: image/jpeg\r\n\r\n'
            + buf.tobytes()
            + b'\r\n'
        )


@app.route('/stream')
def stream():
    return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/')
def index():
    return """
    <html>
    <body style="background:#111;color:#fff;font-family:sans-serif;text-align:center;padding:20px">
        <h2>ESP32-CAM Relay — Raspberry Pi</h2>
        <p>Stream URL for detector.py: <code>/stream</code></p>
        <img src='/stream' style="max-width:800px;border-radius:8px"/>
    </body>
    </html>
    """


if __name__ == '__main__':
    try:
        local_ip = socket.gethostbyname(socket.gethostname())
    except Exception:
        local_ip = "YOUR_PI_NETBIRD_IP"

    print(f"\n  Relay running on port {PORT}")
    print(f"  Browser preview : http://{local_ip}:{PORT}/")
    print(f"  Stream URL      : http://{local_ip}:{PORT}/stream")
    print("  Press Ctrl+C to stop\n")

    app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)
