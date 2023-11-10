#include <ArduinoJson.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>
#include <WiFi.h>
#include "time.h"
#include <ESPAsyncWebSrv.h>
#include <ESPmDNS.h>

Adafruit_MPU6050 mpu;
AsyncWebServer server(8888);
unsigned long lastTimestamp = 0;
const int numElements = 200;  // Number of elements in the array
StaticJsonDocument<300> sensorData[numElements];
int currentIndex = 0;

// Replace with your network credentials
const char* wifi_list[][2] = {
  {"...","atom00001234"},
  {"DESKTOP-3PN2UV9","atom00001234"},
  {"@ENG-WIFI",""},
  {"Maka",""}
};

String hostname = "seismat";

// NTP server to request epoch time
// const char* ntpServer = "pool.ntp.org";

// Function that gets current epoch time
// unsigned long getTime() {
//   struct timeval tv;
//   gettimeofday(&tv, nullptr);
//   return tv.tv_sec * 1000000 + tv.tv_usec;
// }

// Initialize WiFi
void initWiFi() {
  WiFi.mode(WIFI_STA);
  for (int i = 0; i < sizeof(wifi_list)/sizeof(wifi_list[0]); i++) {
    Serial.println();
    Serial.print("Connecting to ");
    Serial.print(wifi_list[i][0]);
    if (wifi_list[i][1] == "") {
        WiFi.begin(wifi_list[i][0]);
    } else {
        WiFi.begin(wifi_list[i][0], wifi_list[i][1]);
    }
    Serial.print(" ");
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      Serial.print(".");
      if (millis() - startTime > 10000) {
        Serial.println("Connection timed out, trying next network...");
        break;
      }
    }
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println();
      Serial.print("WiFi connected to ");
      Serial.println(wifi_list[i][0]);
      Serial.print("IP address: ");
      Serial.println(WiFi.localIP());
      break;
    }
  }
  WiFi.setHostname(hostname.c_str());

  if (!MDNS.begin(hostname)) {
        Serial.println("Error setting up MDNS responder!");
        while(1) {
            delay(1000);
        }
    }
    Serial.println("");
    Serial.println("mDNS responder started");
}

void notFound(AsyncWebServerRequest *request) {
  request->send(404, "application/json", "{\"message\":\"Not found\"}");
}

void updateSensorData() {
  // Get new sensor events with the readings
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // Check if any sensor value is 0
  // if (a.acceleration.x == 0 || a.acceleration.y == 0 || a.acceleration.z == 0 ||
  //     g.gyro.x == 0 || g.gyro.y == 0 || g.gyro.z == 0) {
  //   Serial.println("Output 0 ...Restarting");
  //   // Restart Arduino
  //   ESP.restart();
  // }
  
  // Create a JSON object
  JsonObject jsonData = sensorData[currentIndex].to<JsonObject>();

  // Add sensor data to the JSON object
  unsigned long microsTimestamp = micros();
  jsonData["microsTimestamp"] = microsTimestamp;
  jsonData["accelX"] = a.acceleration.x;
  jsonData["accelY"] = a.acceleration.y;
  jsonData["accelZ"] = a.acceleration.z;

  // Increment the index for the next iteration
  currentIndex = (currentIndex + 1) % numElements;
}


void setup(void) {
  Serial.begin(115200);
  initWiFi();
  // configTime(0, 0, ntpServer);
  while (!Serial) {
    delay(10); // will pause Zero, Leonardo, etc until serial console opens
  }

  // Try to initialize!
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }

  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
  mpu.setGyroRange(MPU6050_RANGE_250_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  delay(100);

  // HTTP server endpoints
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "application/json", "{\"message\":\"Welcome to SeisMAT. To get sensor data, please go to /getsensor\"}");
  });

  server.on("/getsensor", HTTP_GET, [](AsyncWebServerRequest *request) {
    // Create a JSON array as a String
    String jsonArray = "[";
    int validElements = 0;
    for (int i = 0; i < numElements; ++i) {
      if (!sensorData[i].isNull()) {
        String jsonString;
        serializeJson(sensorData[i], jsonString);
        jsonArray += jsonString;
        ++validElements;
        if (validElements < numElements) {
          jsonArray += ",";
        }
      }
    }
    jsonArray += "]";
    request->send(200, "application/json", jsonArray);
  });

  server.onNotFound(notFound);

  // Start the server
  server.begin();
  Serial.println("TCP server started");

  // Add service to MDNS-SD
  MDNS.addService("http", "tcp", 80);
}

void loop() {
  // Update sensor data every 200 microseconds
  if (micros() - lastTimestamp >= 200) {
    updateSensorData();
    lastTimestamp = micros();
  }

  // Your additional loop logic here
}
