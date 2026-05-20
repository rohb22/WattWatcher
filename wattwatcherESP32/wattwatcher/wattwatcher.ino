#include "config.h"
#include "wifi_manager.h"
#include "app_client.h"
#include "relay.h"

static float liveVoltage       = 0.0f;
static float slotCurrents[RELAY_COUNT] = {0.0f, 0.0f, 0.0f, 0.0f};
static float slotPowers[RELAY_COUNT]   = {0.0f, 0.0f, 0.0f, 0.0f};


static bool  uvpTripped            = false;
static bool  ovpTripped            = false;
static bool  systemOverloadTripped = false;
static unsigned long cooldownStartTime = 0;

static unsigned long _lastPublish = 0;

float getACVoltageRMS() {
  int readValue;
  int maxValue = 0;
  int minValue = 4095;
  unsigned long startTime = millis();

  while ((millis() - startTime) < 25) {
    readValue = analogRead(ZMPT_PIN);
    if (readValue > maxValue) maxValue = readValue;
    if (readValue < minValue) minValue = readValue;
  }

  int peakToPeak = maxValue - minValue;
  if (peakToPeak < 150) return 0.0f; 
  return peakToPeak * VOLTAGE_CALIBRATION;
}

float getACCurrentRMS(int pin, float calibrationFactor) {
  int readValue;
  int maxValue = 0;
  int minValue = 4095;
  unsigned long startTime = millis();

  while ((millis() - startTime) < 25) {
    readValue = analogRead(pin);
    if (readValue > maxValue) maxValue = readValue;
    if (readValue < minValue) minValue = readValue;
  }

  int peakToPeak = maxValue - minValue;
  if (peakToPeak < 40) return 0.0f;    
  return peakToPeak * calibrationFactor;
}

void onSocketCommand(int socketId, bool on) {
  relaySet(socketId, on);
  publishSocketState(
    socketId,
    relayIsOn(socketId),
    relayGetWatts(socketId),
    relayGetAmps(socketId),
    relayIsOverload(socketId)
  );
}

void onSocketReset(int socketId) {
  relayResetOverload(socketId);
  publishSocketState(socketId, false, 0.0f, 0.0f, false);
}


void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(ACS_PIN_1, INPUT);
  pinMode(POT_PIN_2, INPUT);
  pinMode(ZMPT_PIN,  INPUT);

  relayBegin();
  wifiBegin();
  appClientBegin(onSocketCommand, onSocketReset);

  Serial.println("Ready.\n");
}

void loop() {
  wifiLoop();
  appClientLoop();

  if (uvpTripped || ovpTripped || systemOverloadTripped) {
    if (millis() - cooldownStartTime > COOLDOWN_DURATION) {
      Serial.println("\n[SYSTEM] Cooldown expired. Resetting protection flags.\n");
      uvpTripped            = false;
      ovpTripped            = false;
      systemOverloadTripped = false;
    }
  }


  slotCurrents[0] = relayIsOn(1) ? getACCurrentRMS(ACS_PIN_1, CURRENT_CALIBRATION_1) : 0.0f;
  delay(2);

  slotCurrents[1] = relayIsOn(2) ? getACCurrentRMS(ACS_PIN_2, CURRENT_CALIBRATION_1) : 0.0f;
  delay(2);

  slotCurrents[2] = relayIsOn(3) ? getACCurrentRMS(ACS_PIN_3, CURRENT_CALIBRATION_1) : 0.0f;
  delay(2)
  slotCurrents[3] = relayIsOn(4) ? getACCurrentRMS(ACS_PIN_4, CURRENT_CALIBRATION_1) : 0.0f;
  delay(2)

  liveVoltage = getACVoltageRMS();

  float totalCurrent = 0.0f;
  for (int i = 0; i < RELAY_COUNT; i++) {
    if (relayIsOn(i + 1)) {
      slotPowers[i]  = liveVoltage * slotCurrents[i];
      totalCurrent  += slotCurrents[i];
    } else {
      slotPowers[i]  = 0.0f;
      slotCurrents[i] = 0.0f;
    }
    relaySetReadings(i + 1, slotPowers[i], slotCurrents[i]);
  }


  if (!uvpTripped && !ovpTripped && !systemOverloadTripped && liveVoltage > 150.0f) {

    if (liveVoltage <= MIN_SAG_VOLTAGE) {
      uvpTripped         = true;
      cooldownStartTime  = millis();
      for (int id = 1; id <= RELAY_COUNT; id++) {
        relayTripOverload(id);
        publishOverloadAlert(id);
        publishSocketState(id, false, 0.0f, 0.0f, true);
      }
      Serial.printf("\nVoltage sag: %.1fV — all lines isolated.\n\n", liveVoltage);
    }

    else if (liveVoltage >= MAX_SURGE_VOLTAGE) {
      ovpTripped         = true;
      cooldownStartTime  = millis();
      for (int id = 1; id <= RELAY_COUNT; id++) {
        relayTripOverload(id);
        publishOverloadAlert(id);
        publishSocketState(id, false, 0.0f, 0.0f, true);
      }
      Serial.printf("\n[OVP] Voltage surge: %.1fV — all lines isolated.\n\n", liveVoltage);
    }

    else if (totalCurrent >= MAX_TOTAL_CURRENT) {
      int worstSlot    = -1;
      float maxCurrent = 0.0f;
      for (int i = 0; i < RELAY_COUNT; i++) {
        if (relayIsOn(i + 1) && slotCurrents[i] > maxCurrent) {
          maxCurrent = slotCurrents[i];
          worstSlot  = i + 1;
        }
      }
      if (worstSlot != -1) {
        systemOverloadTripped = true;
        cooldownStartTime     = millis();
        relayTripOverload(worstSlot);
        publishOverloadAlert(worstSlot);
        publishSocketState(worstSlot, false, 0.0f, 0.0f, true);
        Serial.printf("\n[OVERLOAD] Total %.2fA — Socket %d tripped.\n\n", totalCurrent, worstSlot);
      }
    }

    else {
      for (int id = 1; id <= RELAY_COUNT; id++) {
        if (relayIsOn(id) && slotCurrents[id - 1] >= MAX_SLOT_CURRENT) {
          cooldownStartTime = millis();
          relayTripOverload(id);
          publishOverloadAlert(id);
          publishSocketState(id, false, 0.0f, 0.0f, true);
          Serial.printf("\nSocket %d hit %.2fA — tripped.\n\n", id, slotCurrents[id - 1]);
        }
      }
    }
  }

 
  if (millis() - _lastPublish >= PUBLISH_INTERVAL_MS) {
    _lastPublish = millis();

    float totalWatts = 0.0f;
    for (int i = 0; i < RELAY_COUNT; i++) totalWatts += slotPowers[i];

    static float kwhAccumulator = 0.0f;
    kwhAccumulator += (totalWatts * (PUBLISH_INTERVAL_MS / 1000.0f)) / 3600000.0f;

    publishPower(liveVoltage, totalCurrent, totalWatts, kwhAccumulator);

    for (int id = 1; id <= RELAY_COUNT; id++) {
      publishSocketState(
        id,
        relayIsOn(id),
        relayGetWatts(id),
        relayGetAmps(id),
        relayIsOverload(id)
      );
    }
  }

  static unsigned long _lastLog = 0;
  if (millis() - _lastLog >= 1000) {
    _lastLog = millis();

    Serial.println("\n--- WATTWATCHER TELEMETRY ---");
    Serial.printf("VOLTAGE: %.1f V | ", liveVoltage);
    if      (liveVoltage < 150.0f) Serial.println("STATUS: [AC LINE UNPLUGGED / OFF]");
    else if (uvpTripped)           Serial.println("STATUS: [UNDER-VOLTAGE TRIP]");
    else if (ovpTripped)           Serial.println("STATUS: [OVER-VOLTAGE TRIP]");
    else                           Serial.println("STATUS: [GRID STABLE]");

    for (int i = 0; i < RELAY_COUNT; i++) {
      if (relayIsOverload(i + 1)) {
        Serial.printf("  Socket %d: [OVERLOAD TRIPPED]\n", i + 1);
      } else if (relayIsOn(i + 1)) {
        Serial.printf("  Socket %d: ON  | %.3f A | %.1f W\n", i + 1, slotCurrents[i], slotPowers[i]);
      } else {
        Serial.printf("  Socket %d: OFF\n", i + 1);
      }
    }

    Serial.printf("TOTAL LOAD: %.2f A / %.1f A max\n", totalCurrent, (float)MAX_TOTAL_CURRENT);
    Serial.println("-----------------------------");
  }

  delay(10);
}
