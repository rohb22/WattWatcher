#include "relay.h"


static bool  _isOn[RELAY_COUNT]       = {false};
static bool  _isOverload[RELAY_COUNT] = {false};
static float _watts[RELAY_COUNT]      = {0.0};
static float _amps[RELAY_COUNT]       = {0.0};


static int _idx(int socketId) {
  int i = socketId - 1;
  return (i >= 0 && i < RELAY_COUNT) ? i : -1;
}

static void _writeRelay(int idx, bool on) {
#if RELAY_ACTIVE_LOW
  digitalWrite(RELAY_PINS[idx], on ? LOW : HIGH);
#else
  digitalWrite(RELAY_PINS[idx], on ? HIGH : LOW);
#endif
}


void relayBegin() {
  for (int i = 0; i < RELAY_COUNT; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    _writeRelay(i, false);   
    _isOn[i]       = false;
    _isOverload[i] = false;
    _watts[i]      = 0.0;
    _amps[i]       = 0.0;
  }
  Serial.println("[Relay] All relays initialised OFF");
}

void relaySet(int socketId, bool on) {
  int i = _idx(socketId);
  if (i == -1) return;

  if (_isOverload[i]) {
    Serial.print("[Relay] Socket ");
    Serial.print(socketId);
    Serial.println(" is in overload — reset before turning on");
    return;
  }

  _isOn[i] = on;
  _writeRelay(i, on);

  if (!on) {
    _watts[i] = 0.0;
    _amps[i]  = 0.0;
  }

  Serial.print("[Relay] Socket ");
  Serial.print(socketId);
  Serial.println(on ? " → ON" : " → OFF");
}

void relayTripOverload(int socketId) {
  int i = _idx(socketId);
  if (i == -1) return;

  _isOverload[i] = true;
  _isOn[i]       = false;
  _watts[i]      = 0.0;
  _amps[i]       = 0.0;
  _writeRelay(i, false);   

  Serial.print("[Relay] Socket ");
  Serial.print(socketId);
  Serial.println(" TRIPPED — overload");
}

void relayResetOverload(int socketId) {
  int i = _idx(socketId);
  if (i == -1) return;

  _isOverload[i] = false;
  _isOn[i]       = false;   
  _watts[i]      = 0.0;
  _amps[i]       = 0.0;

  Serial.print("[Relay] Socket ");
  Serial.print(socketId);
  Serial.println(" overload cleared — relay stays OFF");
}

bool relayIsOn(int socketId) {
  int i = _idx(socketId);
  return (i != -1) && _isOn[i];
}

bool relayIsOverload(int socketId) {
  int i = _idx(socketId);
  return (i != -1) && _isOverload[i];
}

void relaySetReadings(int socketId, float watts, float amps) {
  int i = _idx(socketId);
  if (i == -1) return;
  _watts[i] = watts;
  _amps[i]  = amps;
}

float relayGetWatts(int socketId) {
  int i = _idx(socketId);
  return (i != -1) ? _watts[i] : 0.0;
}

float relayGetAmps(int socketId) {
  int i = _idx(socketId);
  return (i != -1) ? _amps[i] : 0.0;
}
