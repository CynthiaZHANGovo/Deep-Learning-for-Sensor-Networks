#include <Arduino_LSM9DS1.h>
#include <Sport_Music_inferencing.h>

static float features[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE];

void setup() {
  Serial.begin(115200);
  while (!Serial);

  if (!IMU.begin()) {
    Serial.println("IMU init failed");
    while (1);
  }

  Serial.println("Ready");
}

void loop() {
  const float sample_interval_ms = 20.0f;   // 50Hz，for tranning time stamp 20ms
  const int axis_count = 3;

  for (size_t i = 0; i < EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE; i += axis_count) {
    float x, y, z;

    while (!IMU.accelerationAvailable()) {
    }

    IMU.readAcceleration(x, y, z);

    features[i + 0] = x;
    features[i + 1] = y;
    features[i + 2] = z;

    delay((int)sample_interval_ms);
  }

  signal_t signal;
  numpy::signal_from_buffer(features, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, &signal);

  ei_impulse_result_t result = { 0 };
  EI_IMPULSE_ERROR err = run_classifier(&signal, &result, false);

  if (err != EI_IMPULSE_OK) {
    Serial.println("Inference failed");
    return;
  }

  int best_ix = 0;
  float best_val = result.classification[0].value;

  for (size_t i = 1; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
    if (result.classification[i].value > best_val) {
      best_val = result.classification[i].value;
      best_ix = i;
    }
  }

  Serial.print("Prediction: ");
  Serial.print(result.classification[best_ix].label);
  Serial.print(" (");
  Serial.print(best_val, 3);
  Serial.println(")");
}