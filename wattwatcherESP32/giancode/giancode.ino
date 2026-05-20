// ============================================================================
// WATTWATCHER: LIVE VOLTAGE & REAL CURRENT MONITORING SYSTEM
// Hardware: ESP32 + 4 Relays + Live ZMPT101B + Real ACS712 (Slot 1) + 1 Pot (Slot 2)
// ============================================================================

// 1. OMNI EXTENSION CORD SPECIFICATIONS & TARGET LIMITS
const float MAX_TOTAL_CURRENT = 10.0;    // OMNI WIRE LIMIT (10 Amps)
const float MAX_SLOT_CURRENT = 6.0;      // INDIVIDUAL SLOT CEILING (6 Amps)

// GRID VOLTAGE THRESHOLDS (Philippine Power Quality Standards)
const float MAX_SURGE_VOLTAGE = 245.0;   // Over-Voltage Protection (OVP) Limit
const float MIN_SAG_VOLTAGE = 195.0;     // Under-Voltage Protection (UVP) Limit

// 2. SENSOR CALIBRATION MULTIPLIERS
const float VOLTAGE_CALIBRATION = 0.167; // Calibrated from your 1320 peak-to-peak wave

// ACS712 Current Calibration: Tweak this after testing with a known load (e.g., a lamp)
// If the displayed current is too low, increase this value slightly.
const float CURRENT_CALIBRATION_1 = 0.0065; 

// 3. HARDWARE PIN ASSIGNMENTS
const int ACS_PIN_1 = 32;                // Real ACS712 Sensor (Slot 1) -> GPIO 32
const int POT_PIN_2 = 33;                // Potentiometer (Slot 2 Current) -> GPIO 33
const int ZMPT_PIN = 36;                 // ZMPT101B Analog Output -> GPIO 36 (VP)
const int RELAY_PINS[4] = {25, 26, 27, 14}; // Relays 1-4 -> GPIO 25, 26, 27, 14

// 4. RUNTIME VARIABLE REGISTERS
float liveVoltage = 0.0;                 
float slotCurrents[4] = {0.0, 0.0, 2.0, 2.0}; // Slots 3 & 4 fixed at 2.0A simulation loads
float slotPowers[4]   = {0.0, 0.0, 0.0, 0.0};
bool slotState[4]      = {true, true, true, true}; 

// Protection States
bool uvpTripped = false;
bool ovpTripped = false;
bool systemOverloadTripped = false;

unsigned long lastDisplayTime = 0;
unsigned long cooldownStartTime = 0;
const unsigned long COOLDOWN_DURATION = 8000; // 8-second safety latch window

// ==========================================
// MATHEMATICAL AC VOLTAGE SAMPLING ENGINE
// ==========================================
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
  int peakToPeakADC = maxValue - minValue;
  if (peakToPeakADC < 150) return 0.0; // Filter out desk noise
  return peakToPeakADC * VOLTAGE_CALIBRATION;
}

// ==========================================
// MATHEMATICAL AC CURRENT SAMPLING ENGINE (ACS712)
// ==========================================
float getACCurrentRMS(int pin, float calibrationFactor) {
  int readValue;
  int maxValue = 0;
  int minValue = 4095;
  unsigned long startTime = millis();
  
  // Sample continuously for 25ms to map the full AC sine wave pattern
  while ((millis() - startTime) < 25) {
    readValue = analogRead(pin);
    if (readValue > maxValue) maxValue = readValue;
    if (readValue < minValue) minValue = readValue;
  }
  
  int peakToPeakADC = maxValue - minValue;
  
  // Filter out ambient magnetic/electrical line noise when appliance is idle
  if (peakToPeakADC < 40) return 0.0; 
  
  // Convert peak-to-peak wave amplitude to actual RMS current Amperes
  return peakToPeakADC * calibrationFactor;
}

// ==========================================
// INITIALIZATION SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=========================================================");
  Serial.println("         WATTWATCHER LIVE GRID MONITOR SYSTEM            ");
  Serial.println("     [REAL ACS712 CURRENT & ZMPT VOLTAGE ACTIVE]         ");
  Serial.println("=========================================================");

  pinMode(ACS_PIN_1, INPUT);
  pinMode(POT_PIN_2, INPUT);
  pinMode(ZMPT_PIN, INPUT);
  
  for (int i = 0; i < 4; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    digitalWrite(RELAY_PINS[i], LOW); // Close relays (Power track active)
  }
  Serial.println("System online. Reading live analog sensor grids...\n");
}

// ==========================================
// MAIN TRACKING & EXECUTION LOOP
// ==========================================
void loop() {
  
  // ------------------------------------------------------------------
  // PART 1: SAFETY COOLDOWN SYSTEM
  // ------------------------------------------------------------------
  if (uvpTripped || ovpTripped || systemOverloadTripped || !slotState[0] || !slotState[1]) {
    if (millis() - cooldownStartTime > COOLDOWN_DURATION) {
      Serial.println("\n[SYSTEM] Environmental timeout cleared. Resetting lines...\n");
      uvpTripped = false; ovpTripped = false; systemOverloadTripped = false;
      for (int i = 0; i < 4; i++) {
        slotState[i] = true;
        digitalWrite(RELAY_PINS[i], LOW); 
      }
      delay(200);
    }
  }

  // ------------------------------------------------------------------
  // PART 2: DYNAMIC HARDWARE SAMPLING
  // ------------------------------------------------------------------
  // Read Potentiometer 2 for Slot 2
  slotCurrents[1] = (analogRead(POT_PIN_2) / 4095.0) * 7.5; 
  delay(2); // Short 2ms hardware settling gap for the internal ADC multiplexer
  
  // Read real-world ACS712 wave data for Slot 1
  if (slotState[0]) {
    slotCurrents[0] = getACCurrentRMS(ACS_PIN_1, CURRENT_CALIBRATION_1);
  } else {
    slotCurrents[0] = 0.0;
  }
  delay(2); // Short 2ms hardware settling gap
  
  // Static simulation arrays for channels 3 and 4
  slotCurrents[2] = slotState[2] ? 2.0 : 0.0;
  slotCurrents[3] = slotState[3] ? 2.0 : 0.0;

  // Execute the voltage wave processing loop
  liveVoltage = getACVoltageRMS();

  // Compute instantaneous true wattages across all lines
  float combinedCurrentSum = 0.0;
  for (int i = 0; i < 4; i++) {
    if (slotState[i]) {
      slotPowers[i] = liveVoltage * slotCurrents[i];
      combinedCurrentSum += slotCurrents[i];
    } else {
      slotPowers[i] = 0.0;
      slotCurrents[i] = 0.0; 
    }
  }

  // ------------------------------------------------------------------
  // PART 3: ACTIVE SECURITY PROTECTION TRIAGE
  // ------------------------------------------------------------------
  if (!uvpTripped && !ovpTripped && !systemOverloadTripped && liveVoltage > 150.0) {

    // --- TRACK 1: UNDER-VOLTAGE PROTECTOR (UVP) ---
    if (liveVoltage <= MIN_SAG_VOLTAGE) {
      uvpTripped = true; cooldownStartTime = millis();
      for (int i = 0; i < 4; i++) { slotState[i] = false; digitalWrite(RELAY_PINS[i], HIGH); } 
      Serial.printf("\n[⚠️ CRITICAL UVP] REAL VOLTAGE SAG DETECTED: %.1fV! Isolating lines.\n\n", liveVoltage);
    }
    
    // --- TRACK 2: OVER-VOLTAGE PROTECTOR (OVP) ---
    else if (liveVoltage >= MAX_SURGE_VOLTAGE) {
      ovpTripped = true; cooldownStartTime = millis();
      for (int i = 0; i < 4; i++) { slotState[i] = false; digitalWrite(RELAY_PINS[i], HIGH); } 
      Serial.printf("\n[⚠️ CRITICAL OVP] REAL POWER SURGE DETECTED: %.1fV! Intercepting spike.\n\n", liveVoltage);
    }
    
    // --- TRACK 3: MAXIMUM CURRENT MONITOR (OMNI WIRE PROTECTION) ---
    else if (combinedCurrentSum >= MAX_TOTAL_CURRENT) {
      int heaviestOffendingSlot = -1;
      float maxCurrent = 0.0;
      for (int i = 0; i < 4; i++) {
        if (slotState[i] && slotCurrents[i] > maxCurrent) {
          maxCurrent = slotCurrents[i]; heaviestOffendingSlot = i;
        }
      }
      if (heaviestOffendingSlot != -1) {
        slotState[heaviestOffendingSlot] = false;
        digitalWrite(RELAY_PINS[heaviestOffendingSlot], HIGH); 
        cooldownStartTime = millis();
        Serial.printf("\n[⚠️ OVERLOAD] CURRENT REACHED %.2fA! Isolated Slot %d safely.\n\n", combinedCurrentSum, heaviestOffendingSlot + 1);
      }
    }
    
    // --- TRACK 4: OUTLET INDIVIDUAL OVER-CURRENT TIMEOUT ---
    else {
      for (int i = 0; i < 4; i++) {
        if (slotState[i] && slotCurrents[i] >= MAX_SLOT_CURRENT) {
          slotState[i] = false;
          cooldownStartTime = millis();
          digitalWrite(RELAY_PINS[i], HIGH); 
          Serial.printf("\n[⚠️ SLOT OVERLOAD] Slot %d hit %.2fA! Line isolated cleanly.\n\n", i + 1, slotCurrents[i]);
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // PART 4: TELEMETRY LOGGER OUTPUT
  // ------------------------------------------------------------------
  if (millis() - lastDisplayTime > 1000) {
    lastDisplayTime = millis();

    Serial.println("\n--- WATTWATCHER HARDWARE SYSTEM TELEMETRY ---");
    Serial.printf("GRID CURRENT VOLTAGE: %.1f V AC | ", liveVoltage);
    if (liveVoltage < 150.0) Serial.println("STATUS: [⚠️ AC HIGH-VOLTAGE LINE UNPLUGGED / OFF]");
    else if (uvpTripped) Serial.println("STATUS: [❌ ALERT - UNDER-VOLTAGE CRASH]");
    else if (ovpTripped) Serial.println("STATUS: [❌ ALERT - OVER-VOLTAGE DAMAGE SURGE]");
    else Serial.println("STATUS: [● GRID STABLE / ACTIVE]");

    for (int i = 0; i < 4; i++) {
      if (slotState[i]) {
        Serial.printf("  Outlet Terminal %d: ONLINE  | %.2f A | %.1f W\n", i + 1, slotCurrents[i], slotPowers[i]);
      } else {
        Serial.printf("  Outlet Terminal %d: [❌ TRIPPED ISOLATED]\n", i + 1);
      }
    }
    
    float totalCurrentReading = slotCurrents[0] + slotCurrents[1] + slotCurrents[2] + slotCurrents[3];
    Serial.printf("TOTAL DIALED OUTLET LOAD: %.2f A / 10.00 A\n", totalCurrentReading);
    Serial.println("----------------------------------------------");
  }

  delay(10); 
}