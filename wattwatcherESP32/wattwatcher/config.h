#pragma once

#ifndef MQTT_HOST
  #define MQTT_HOST "9a3aac49fda9471f9c16eea84a23c15b.s1.eu.hivemq.cloud"
#endif

#ifndef MQTT_PORT
  #define MQTT_PORT 8883
#endif

#ifndef MQTT_USER
  #define MQTT_USER "esp32-test"
#endif

#ifndef MQTT_PASS
  #define MQTT_PASS "Microproject0"
#endif

#define MQTT_CLIENT_ID "wattwatcher_esp32_" __TIME__

#define WIFI_AP_NAME     "WattWatcher-Setup"
#define WIFI_AP_PASSWORD "wattwatcher"
#define WIFI_TIMEOUT_SEC 180

#define RELAY_COUNT      4
#define RELAY_ACTIVE_LOW true

static const int RELAY_PINS[RELAY_COUNT] = {25, 26, 27, 14};


#define LED_WIFI  2
#define LED_MQTT  4

#define ACS_PIN_1   32    // Real ACS712 current sensor — Slot 1
#define ACS_PIN_2   33  
#define ACS_PIN_3   34
#define ACS_PIN_4   35 

#define ZMPT_PIN    36    // ZMPT101B voltage sensor (GPIO 36 / VP)


#define VOLTAGE_CALIBRATION    0.167f   // Tuned for 1320 peak-to-peak reading
#define CURRENT_CALIBRATION_1  0.0065f  // ACS712 Slot 1 — tune with known load

#define MAX_TOTAL_CURRENT  10.0f   // OMNI wire limit (A)
#define MAX_SLOT_CURRENT    6.0f   // Per-slot ceiling (A)
#define MAX_SURGE_VOLTAGE 245.0f   // Over-voltage protection limit (V)
#define MIN_SAG_VOLTAGE   195.0f   // Under-voltage protection limit (V)
#define COOLDOWN_DURATION  8000UL  // Safety latch window after trip (ms)


#define TOPIC_POWER          "wattwatcher/sensor/power"
#define TOPIC_SOCKET_STATE_1 "wattwatcher/socket/1/state"
#define TOPIC_SOCKET_STATE_2 "wattwatcher/socket/2/state"
#define TOPIC_SOCKET_STATE_3 "wattwatcher/socket/3/state"
#define TOPIC_SOCKET_STATE_4 "wattwatcher/socket/4/state"
#define TOPIC_ALERT          "wattwatcher/alert"

#define TOPIC_SOCKET_SET_1   "wattwatcher/socket/1/set"
#define TOPIC_SOCKET_SET_2   "wattwatcher/socket/2/set"
#define TOPIC_SOCKET_SET_3   "wattwatcher/socket/3/set"
#define TOPIC_SOCKET_SET_4   "wattwatcher/socket/4/set"

#define PUBLISH_INTERVAL_MS  5000UL