"""Detect MediaPipe Face Landmarker points (478, Apache-2.0) in images.

Runs in a separate Python with `mediapipe` installed (Blender's Python has
none); face_fit.py calls it as a subprocess:

    <venv>/bin/python -I face_landmarks_detect.py <model.task> <out.json> <image> [<image> ...]

Writes {image: {"size": [w, h], "points": [[x_px, y_px, z_px], ...]}}; z is
MediaPipe's relative depth scaled by the image width (smaller = nearer).
"""
import json
import sys

import mediapipe as mp
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import FaceLandmarker, FaceLandmarkerOptions


def main():
    model, out, *images = sys.argv[1:]
    options = FaceLandmarkerOptions(base_options=BaseOptions(model_asset_path=model), num_faces=1)
    result = {}
    with FaceLandmarker.create_from_options(options) as landmarker:
        for path in images:
            image = mp.Image.create_from_file(path)
            found = landmarker.detect(image).face_landmarks
            w, h = image.width, image.height
            result[path] = {"size": [w, h], "points": [[p.x * w, p.y * h, p.z * w] for p in found[0]]}\
                if found else None
    with open(out, "w") as f:
        json.dump(result, f)


if __name__ == "__main__":
    main()
