#include <Arduino_LSM9DS1.h>

void setup() {
  Serial.begin(115200);

  while (!Serial);   // confirming the connection of the serial

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }
}

void loop() {

  float ax, ay, az;

  if (IMU.accelerationAvailable()) {

    IMU.readAcceleration(ax, ay, az);

    // ⚠️ the output should be：ax,ay,az
    Serial.print(ax, 4);
    Serial.print(",");
    Serial.print(ay, 4);
    Serial.print(",");
    Serial.println(az, 4);

    delay(50);   // 20HZ waiting
  }
}