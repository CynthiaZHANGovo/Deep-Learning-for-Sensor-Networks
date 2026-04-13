#include <Sport_Music_inferencing.h>

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("EI library included.");
  Serial.print("Frame size: ");
  Serial.println(EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE);
  Serial.print("Label count: ");
  Serial.println(EI_CLASSIFIER_LABEL_COUNT);
}

void loop() {
  delay(1000);
}