#include "wifi_manager.h"

static WiFiManager _wm;
static bool _portalActive = false;


static void _onPortalStart() {
  _portalActive = true;
  Serial.println("[WiFi] No saved credentials — captive portal open");
  Serial.print("[WiFi] Connect to AP: ");
  Serial.println(WIFI_AP_NAME);
  Serial.print("[WiFi] Then open:    http://");
  Serial.println(WiFi.softAPIP());

  digitalWrite(LED_WIFI, LOW);
}

static void _onPortalSave() {
  _portalActive = false;
  Serial.println("[WiFi] Credentials saved — connecting…");
}


void wifiBegin() {
  pinMode(LED_WIFI, OUTPUT);
  digitalWrite(LED_WIFI, LOW);

  _wm.setConfigPortalTimeout(WIFI_TIMEOUT_SEC);
  _wm.setAPCallback(_onPortalStart);
  _wm.setSaveConfigCallback(_onPortalSave);

  _wm.setClass("invert");

  Serial.println("[WiFi] Attempting to connect with saved credentials…");

  bool connected = _wm.autoConnect(WIFI_AP_NAME, WIFI_AP_PASSWORD);

  if (connected) {
    _portalActive = false;
    digitalWrite(LED_WIFI, HIGH);   
    Serial.print("[WiFi] Connected. IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("[WiFi] Portal timed out. Running offline.");
  }
}

bool wifiIsConnected() {
  return WiFi.status() == WL_CONNECTED;
}

void wifiLoop() {
  if (wifiIsConnected()) {
    digitalWrite(LED_WIFI, HIGH);
    _portalActive = false;
  } else {
    digitalWrite(LED_WIFI, (millis() / 500) % 2);
  }
}

void wifiForcePortal() {
  Serial.println("[WiFi] Force-opening config portal…");
  _wm.resetSettings(); 
  _wm.startConfigPortal(WIFI_AP_NAME, WIFI_AP_PASSWORD);
}
