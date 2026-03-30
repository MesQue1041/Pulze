# Pulze – Intelligent Adaptive Real-Time Heart Rate Zone System for Cycling

Pulze is a research‑driven mobile application that improves heart rate zone training for cyclists. It addresses **cardiovascular drift**—the gradual rise in heart rate during steady‑state exercise even when effort remains constant—by estimating and subtracting drift in real time. The result is an **effective heart rate** that better reflects true physical effort while preserving standard HRmax‑based zone definitions.

This repository contains the complete codebase for the mobile app (Flutter) and the research pipeline (Python notebooks) used to develop and validate the drift‑correction model.

---

## Overview

**Problem**  
Conventional heart rate zones are static. During long rides, cardiovascular drift can push a cyclist’s heart rate into a higher zone even though the actual workload hasn’t increased. This leads to misleading feedback and suboptimal training.

**Solution**  
Pulze estimates the drift component in real time using only a heart rate monitor and GPS (no power meter required). It produces an **effective heart rate** that is used for zone classification, keeping the original zone boundaries unchanged but making the interpretation more accurate during prolonged effort.

**Key Contributions**  
- A novel real‑time drift estimation algorithm based on workload‑adjusted expected heart rate.  
- A complete mobile app (Flutter) that implements the algorithm with BLE heart rate straps and GPS.  
- A research‑grade Python pipeline for model development, validation, and offline analysis.  
- Evaluation on a large public cycling dataset (FitRec Endomondo) showing significant improvement in late‑ride heart rate error for more than 55% of evaluated rides.

---

## Features

- **Real‑time drift correction** – Estimates drift and displays effective heart rate alongside raw HR.  
- **Zone classification** – Uses standard HRmax‑based zones (customizable in settings).  
- **BLE heart rate monitor support** – Connect any standard heart rate strap.  
- **GPS‑based workload proxy** – Computes virtual power from speed, altitude, and user weight (no power meter needed).  
- **Live ride recording** – Saves all sensor data and correction parameters to CSV for later analysis.  
- **Ride history** – View past rides, replay them with the correction logic, and export/share data.  
- **Demo player** – Replay pre‑recorded rides to see the correction effect.  
- **Settings** – Adjust HRmax, custom zones, rider weight, and drift start time.  
- **Foreground service (Android)** – Keeps recording when the screen is off.

---

## Tech Stack

| Component          | Technology                                      |
|--------------------|-------------------------------------------------|
| Mobile Framework   | Flutter (Dart)                                  |
| BLE                | flutter_reactive_ble                            |
| GPS & Location     | geolocator                                      |
| Data Persistence   | CSV (via path_provider, csv)                    |
| Charts             | fl_chart                                        |
| Background Service | flutter_foreground_task (Android only)          |
| Research Pipeline  | Python (pandas, numpy, scikit‑learn, scipy)     |
| Model Deployment   | JSON export (model weights and parameters)      |

---
