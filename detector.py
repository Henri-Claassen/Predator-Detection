import cv2
import numpy as np
from datetime import datetime
from ultralytics import YOLO
import time
from database_connect import insert_predator

# ===========================================================
# SECTION 1 — Setting up the model
# ===========================================================

VIDEO_SOURCE = "http://192.168.0.129:5000/stream"   # <-- CHANGE THIS To Stream URL

MODEL_NAME = "yolov8s-oiv7.pt"

CONFIDENCE_THRESHOLD = 0.50

PROCESS_EVERY_N_FRAMES = 3
    
DETECTION_COOLDOWN_SECONDS = 15

PREDATOR_CLASSES = [
    "fox",
    "raccoon",
    "hawk",
    "eagle",
    "owl",
    "snake",
    "cat",
    "dog",
]

print(f"Loading YOLOv8 model: {MODEL_NAME}")
print("(First run will auto-download the model — this is normal)")
model = YOLO(MODEL_NAME)
print("Model loaded successfully.\n")

#Variables where data is stored about predator detections
detection_time: datetime | None = None      
predator_type: str | None = None           
confidence_score: float | None = None       
screenshot_blob: bytes | None = None        

# Internal cooldown tracker (prevents duplicate detections of the same predator)
last_detection_times: dict[str, datetime] = {}


# ===========================================================
# SECTION 2 — Functions for storing the data
# ===========================================================

def capture_screenshot_as_blob(frame: np.ndarray) -> bytes:
    encode_params = [cv2.IMWRITE_JPEG_QUALITY, 90]   # 90% quality = good balance
    success, buffer = cv2.imencode('.jpg', frame, encode_params)

    if not success:
        print("Warning: Could not encode screenshot")
        return b""

    return buffer.tobytes()

def is_on_cooldown(predator_name: str) -> bool:
    now = datetime.now()
    last = last_detection_times.get(predator_name)

    if last is None:
        return False  # Never seen before — not on cooldown

    seconds_since_last = (now - last).total_seconds()
    return seconds_since_last < DETECTION_COOLDOWN_SECONDS


def process_detections(frame: np.ndarray, results) -> bool:
    global detection_time, predator_type, confidence_score
    global screenshot_blob, last_detection_times

    any_predator_found = False

    # results is a list (one entry per image — we always send one image at a time)
    for result in results:
        boxes = result.boxes
        if boxes is None or len(boxes) == 0:
            continue   # No detections in this frame

        # Loop through every detected object in the frame
        for box in boxes:

            # Get the class ID number (e.g. 15 = "cat" in COCO dataset)
            class_id = int(box.cls[0])

            # Convert class ID to human-readable name using the model's class list
            # model.names is a dict like {0: "person", 15: "cat", 16: "dog", ...}
            class_name = model.names[class_id].lower()

            # Get confidence (0.0 to 1.0)
            conf = float(box.conf[0])

            # Skip if below our confidence threshold
            if conf < CONFIDENCE_THRESHOLD:
                continue

            # Skip if this is not a predator we care about
            if class_name not in PREDATOR_CLASSES:
                continue

            # Skip if we just logged this predator recently
            if is_on_cooldown(class_name):
                continue

            # ---- A new predator detection! ----
            any_predator_found = True
            now = datetime.now()

            # Update the global detection variables
            detection_time = now
            predator_type = class_name
            confidence_score = round(conf, 4)   # e.g. 0.8734 → 0.8734
            screenshot_blob = capture_screenshot_as_blob(frame)

            # Update the cooldown tracker
            last_detection_times[class_name] = now

            #Call the database function to insert the new predator detection into the database
            insert_predator(detection_time, confidence_score, predator_type, screenshot_blob)

            # Print to VS Code terminal so you can see what's happening
            print("\n" + "!" * 50)
            print("  PREDATOR DETECTED")
            print("!" * 50)
            print(f"  Type        : {predator_type.upper()}")
            print(f"  Confidence  : {confidence_score * 100:.1f}%")
            print(f"  Time        : {detection_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"  Screenshot  : {len(screenshot_blob):,} bytes (LONGBLOB ready)")
            print("!" * 50)

    return any_predator_found


# ===========================================================
# SECTION 3 — MAIN LOOP
# ===========================================================

def main():
    print("=" * 55)
    print("  Chicken Coop Predator Detector")
    print("=" * 55)
    print(f"  Video source : {VIDEO_SOURCE}")
    print(f"  Model        : {MODEL_NAME}")
    print(f"  Predators    : {', '.join(PREDATOR_CLASSES)}")
    print(f"  Confidence   : >= {CONFIDENCE_THRESHOLD * 100:.0f}%")
    print("=" * 55)
    print("  Connecting to stream...")

    cap = cv2.VideoCapture(VIDEO_SOURCE)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    if not cap.isOpened():
        print("\nERROR: Could not connect to video source!")
        print("Check that:")
        print("  1. stream_server.py is running on your Raspberry Pi")
        print(f"  2. The IP address in VIDEO_SOURCE is correct: {VIDEO_SOURCE}")
        print("  3. Both devices are on the same network (or ngrok is set up)")
        return

    print("  Connected! Starting detection...\n")

    frame_count = 0

    try:
        while True:
            ret, frame = cap.read()

            if not ret or frame is None:
                print("Stream lost. Waiting for stream to come back...")
                cap.release()
                while True:
                    time.sleep(5)
                    cap = cv2.VideoCapture(VIDEO_SOURCE)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    if cap.isOpened():
                        ret_test, _ = cap.read()
                        if ret_test:
                            print("Stream reconnected! Resuming detection...\n")
                            break
                    cap.release()
                    print("Stream still offline, retrying in 5 seconds...")
                frame_count = 0
                continue

            frame_count += 1

            if frame_count % PROCESS_EVERY_N_FRAMES == 0:
                results = model(frame, verbose=False)
                process_detections(frame, results)

    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        cap.release()

if __name__ == "__main__":
    main()
