"""
=============================================================
  stream_server.py  —  Run this on a Raspberry Pi
=============================================================

HOW TO RUN ON A RASPBERRY PI:
  1. Copy this file to your Pi (USB, SSH, or git clone)
  2. Install dependencies:
        pip install flask opencv-python
  3. Run it:
        python stream_server.py
  4. It will print your stream URL, e.g.:
        Stream running at: http://INSERT_IP_HERE:5000/stream
  5. Copy that URL into detector.py on your laptop

HOW TO FIND YOUR PI'S IP ADDRESS:
  On the Pi, run:  hostname -I
  It will show something like: INSERT_IP_HERE

FOR CROSS-NETWORK STREAMING (your friend's house → your house):
  1. Install ngrok on the Pi:   https://ngrok.com/download
  2. While stream_server.py is running, open a second terminal and run:
        ngrok http 5000
  3. Ngrok gives you a public URL like: https://abc123.ngrok-free.app
  4. Your stream URL becomes: https://abc123.ngrok-free.app/stream
  5. Put that URL in detector.py on your laptop

WHEN YOU GET THE ESP32-CAM:
  - Flash the CameraWebServer example from Arduino IDE
  - Set your WiFi credentials in the sketch
  - After flashing, open Serial Monitor to see the camera's IP
  - Your stream URL will be: http://[ESP32-IP]/stream
  - Just change VIDEO_SOURCE in detector.py to that URL
  - You can stop running this file entirely

=============================================================
"""

from flask import Flask, Response
import cv2
import socket

# -------------------------------------------------------
# CONFIGURATION — change these if needed
# -------------------------------------------------------

CAMERA_INDEX = 0        # 0 = first webcam. Try 1 or 2 if wrong camera opens
PORT = 5000             # The port the stream runs on
FRAME_WIDTH = 640       # Stream resolution width  (lower = faster stream)
FRAME_HEIGHT = 480      # Stream resolution height
JPEG_QUALITY = 70       # 0-100. Lower = smaller file size = faster stream


# -------------------------------------------------------
# SETUP
# -------------------------------------------------------

app = Flask(__name__)
camera = cv2.VideoCapture(CAMERA_INDEX)

# Set resolution
camera.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
camera.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)

if not camera.isOpened():
    print(f"ERROR: Could not open camera at index {CAMERA_INDEX}")
    print("Try changing CAMERA_INDEX to 1 or 2 at the top of this file")
    exit(1)


# -------------------------------------------------------
# STREAM GENERATOR
# -------------------------------------------------------

def generate_frames():
    """
    This function runs in an infinite loop, capturing frames
    from the webcam and sending them as a continuous MJPEG stream.
    
    MJPEG (Motion JPEG) is just a stream of JPEG images sent
    one after another. OpenCV can read this format natively,
    which is exactly what the ESP32-CAM also outputs.
    """
    while True:
        # Grab a frame from the webcam
        success, frame = camera.read()

        if not success:
            # If we can't read a frame, skip and try again
            print("Warning: Could not read frame from camera")
            continue

        # Compress the frame as a JPEG image (bytes in memory, not saved to disk)
        encode_params = [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY]
        success, buffer = cv2.imencode('.jpg', frame, encode_params)

        if not success:
            continue

        frame_bytes = buffer.tobytes()

        # Yield each frame in MJPEG boundary format
        # This is the standard format that browsers and OpenCV understand
        yield (
            b'--frame\r\n'
            b'Content-Type: image/jpeg\r\n\r\n'
            + frame_bytes +
            b'\r\n'
        )


# -------------------------------------------------------
# ROUTES (URLs)
# -------------------------------------------------------

@app.route('/stream')
def video_feed():
    """
    This is the URL your laptop will connect to.
    e.g. http://INSERT_IP_HERE:5000/stream

    It returns a continuous MJPEG video stream.
    The ESP32-CAM also serves its stream at /stream by default.
    """
    return Response(
        generate_frames(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )


@app.route('/')
def index():
    """
    Visit this in a browser to test the stream visually.
    e.g. http://INSERT_IP_HERE:5000/
    """
    return """
    <html>
        <body style="background:#111;margin:0;display:flex;flex-direction:column;align-items:center;padding:20px;font-family:sans-serif;color:white">
            <h2>Raspberry Pi Camera Stream</h2>
            <p>Stream URL for detector.py: <code>/stream</code></p>
            <img src='/stream' style="max-width:640px;border-radius:8px"/>
        </body>
    </html>
    """


# -------------------------------------------------------
# START THE SERVER
# -------------------------------------------------------

if __name__ == '__main__':
    # Get local IP to show user a helpful URL
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
    except Exception:
        local_ip = "YOUR_PI_IP"

    print("\n" + "="*55)
    print("  Raspberry Pi Stream Server — Running")
    print("="*55)
    print(f"  Local stream URL :  http://{local_ip}:{PORT}/stream")
    print(f"  Browser preview  :  http://{local_ip}:{PORT}/")
    print(f"  Camera index     :  {CAMERA_INDEX}")
    print(f"  Resolution       :  {FRAME_WIDTH}x{FRAME_HEIGHT}")
    print(f"  JPEG quality     :  {JPEG_QUALITY}%")
    print("="*55)
    print("  Press Ctrl+C to stop")
    print("="*55 + "\n")

    # host='0.0.0.0' makes the server visible on your local network
    # (not just on the Pi itself)
    app.run(
        host='0.0.0.0',
        port=PORT,
        debug=False,
        threaded=True   # Allows multiple connections at once
    )
