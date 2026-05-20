#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

void appClientBegin(
  void (*onSocketCommand)(int socketId, bool on),
  void (*onSocketReset)(int socketId)
);


void appClientLoop();


void publishPower(float voltage, float current, float watts, float kwhToday);

void publishSocketState(int socketId, bool isOn, float watts, float amps, bool isOverload);

void publishOverloadAlert(int socketId);


bool appIsConnected();
