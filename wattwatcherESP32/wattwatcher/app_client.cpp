#include "app_client.h"
#include <WiFiClientSecure.h>
#include <MQTT.h>          


static WiFiClientSecure  _wifiClient;
static MQTTClient        _mqtt(512); 

static void (*_onSocketCommand)(int, bool) = nullptr;
static void (*_onSocketReset)(int)         = nullptr;

static unsigned long _lastReconnectAttempt = 0;
static const unsigned long RECONNECT_INTERVAL_MS = 5000;

static const char* SET_TOPICS[RELAY_COUNT] = {
  TOPIC_SOCKET_SET_1,
  TOPIC_SOCKET_SET_2,
  TOPIC_SOCKET_SET_3,
  TOPIC_SOCKET_SET_4,
};


static void _onMessage(String& topic, String& payload) {
  Serial.print("[MQTT] ← ");
  Serial.print(topic);
  Serial.print("  ");
  Serial.println(payload);

  int socketId = -1;
  for (int i = 0; i < RELAY_COUNT; i++) {
    if (topic == SET_TOPICS[i]) {
      socketId = i + 1;   
      break;
    }
  }
  if (socketId == -1) return;   
  StaticJsonDocument<64> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.print("[MQTT] JSON parse error: ");
    Serial.println(err.c_str());
    return;
  }

  if (doc.containsKey("reset")) {
    if (_onSocketReset) _onSocketReset(socketId);
  } else if (doc.containsKey("on")) {
    bool on = doc["on"].as<bool>();
    if (_onSocketCommand) _onSocketCommand(socketId, on);
  }
}

static bool _mqttConnect() {
  Serial.print("[MQTT] Connecting to ");
  Serial.print(MQTT_HOST);
  Serial.print(":");
  Serial.println(MQTT_PORT);

  _wifiClient.setInsecure();

  _mqtt.begin(MQTT_HOST, MQTT_PORT, _wifiClient);
  _mqtt.onMessage(_onMessage);

  if (!_mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS)) {
    Serial.print("[MQTT] Failed. rc=");
    Serial.println(_mqtt.lastError());
    return false;
  }

  Serial.println("[MQTT] Connected");
  digitalWrite(LED_MQTT, HIGH);

  for (int i = 0; i < RELAY_COUNT; i++) {
    _mqtt.subscribe(SET_TOPICS[i], 1);
    Serial.print("[MQTT] Subscribed: ");
    Serial.println(SET_TOPICS[i]);
  }

  return true;
}


void appClientBegin(
  void (*onSocketCommand)(int socketId, bool on),
  void (*onSocketReset)(int socketId)
) {
  pinMode(LED_MQTT, OUTPUT);
  digitalWrite(LED_MQTT, LOW);

  _onSocketCommand = onSocketCommand;
  _onSocketReset   = onSocketReset;

  if (WiFi.status() == WL_CONNECTED) {
    _mqttConnect();
  } else {
    Serial.println("[MQTT] Skipping connect — WiFi not ready");
  }
}

void appClientLoop() {
  if (!_mqtt.connected()) {
    digitalWrite(LED_MQTT, LOW);

    unsigned long now = millis();
    if (now - _lastReconnectAttempt >= RECONNECT_INTERVAL_MS) {
      _lastReconnectAttempt = now;
      if (WiFi.status() == WL_CONNECTED) {
        _mqttConnect();
      }
    }
  }

  _mqtt.loop(); 
}

bool appIsConnected() {
  return _mqtt.connected();
}


void publishPower(float voltage, float current, float watts, float kwhToday) {
  if (!appIsConnected()) return;

  StaticJsonDocument<128> doc;
  doc["voltage"] = round(voltage * 10) / 10.0;
  doc["current"] = round(current * 1000) / 1000.0;
  doc["watts"]   = round(watts * 10) / 10.0;
  doc["kwh"]     = round(kwhToday * 10000) / 10000.0;

  char buf[128];
  serializeJson(doc, buf);

  _mqtt.publish(TOPIC_POWER, buf, false, 1);

  Serial.print("[MQTT] → power: ");
  Serial.println(buf);
}

void publishSocketState(
  int socketId, bool isOn, float watts, float amps, bool isOverload
) {
  if (!appIsConnected()) return;
  if (socketId < 1 || socketId > RELAY_COUNT) return;

  StaticJsonDocument<128> doc;
  doc["on"]       = isOn && !isOverload;
  doc["watts"]    = round(watts * 10) / 10.0;
  doc["amps"]     = round(amps * 1000) / 1000.0;
  doc["overload"] = isOverload;

  char buf[128];
  serializeJson(doc, buf);

  char topic[40];
  snprintf(topic, sizeof(topic), "wattwatcher/socket/%d/state", socketId);

  _mqtt.publish(topic, buf, false, 1);

  Serial.print("[MQTT] → socket ");
  Serial.print(socketId);
  Serial.print(": ");
  Serial.println(buf);
}

void publishOverloadAlert(int socketId) {
  if (!appIsConnected()) return;

  StaticJsonDocument<128> doc;
  doc["type"]    = "overload";
  doc["socket"]  = socketId;

  char msg[48];
  snprintf(msg, sizeof(msg), "Socket %d overload! Relay tripped.", socketId);
  doc["message"] = msg;

  char buf[128];
  serializeJson(doc, buf);

  _mqtt.publish(TOPIC_ALERT, buf, false, 1);

  Serial.print("[MQTT] → alert: ");
  Serial.println(buf);
}
