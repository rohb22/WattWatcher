#pragma once

// calls tripOverload() when it
//  detects overcurrent, and calls setRelayWatts/Amps before publishing

#include <Arduino.h>
#include "config.h"


void relayBegin();


void relaySet(int socketId, bool on);

void relayTripOverload(int socketId);

void relayResetOverload(int socketId);


bool relayIsOn(int socketId);
bool relayIsOverload(int socketId);

void  relaySetReadings(int socketId, float watts, float amps);
float relayGetWatts(int socketId);
float relayGetAmps(int socketId);
