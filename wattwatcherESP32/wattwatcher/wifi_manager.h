#pragma once

#include <WiFiManager.h>
#include "config.h"

void     wifiBegin();

bool     wifiIsConnected();

void     wifiLoop();

void     wifiForcePortal();
