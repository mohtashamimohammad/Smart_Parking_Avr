# Smart Parking System 🚗

An embedded **Smart Parking System** implemented using an **ATmega328P microcontroller** and **AVR Assembly**.
The project was developed and tested as a Proteus-based simulation using **Atmel Studio 7**.

## Overview

The system simulates a smart parking gate that monitors available parking spaces, detects vehicle entry and exit, controls a servo gate, and displays the parking status on a 16×2 LCD.

The initial parking capacity can be configured using a 4×3 keypad. After setup, vehicles can enter automatically through a simulated pulse input or manually using the keypad.

## Features

* 16×2 LCD with 4-bit interface
* Configurable parking capacity from **1 to 99 spaces**
* 4×3 matrix keypad
* Vehicle entry detection using a pulse input
* Manual/demo vehicle entry using `#`
* Vehicle exit using a push button
* Manual/demo vehicle exit using `*`
* Free-space counter
* Parking-full detection
* Servo-controlled entrance gate
* Green LED for allowed vehicle entry
* Red LED when the parking area is full
* Buzzer warning when the parking area is full
* Input debouncing and event latching
* Proteus-compatible simulation

## Hardware / Simulation Components

* ATmega328P
* 16×2 LCD
* 4×3 Matrix Keypad
* Servo Motor
* Push Button
* Pulse Generator / Digital Input
* Green LED
* Red LED
* Buzzer
* +5V Power Supply

## Pin Configuration

| Component       | ATmega328P Pin |
| --------------- | -------------- |
| LCD RS          | PB0            |
| LCD E           | PB1            |
| LCD D4          | PB2            |
| LCD D5          | PB3            |
| LCD D6          | PB4            |
| LCD D7          | PB5            |
| Keypad Row A    | PC0            |
| Keypad Row B    | PC1            |
| Keypad Row C    | PC2            |
| Keypad Row D    | PC3            |
| Keypad Column 1 | PC4            |
| Keypad Column 2 | PC5            |
| Keypad Column 3 | PD7            |
| Buzzer          | PD0            |
| Red LED         | PD1            |
| Vehicle Pulse   | PD2            |
| Exit Button     | PD3            |
| Green LED       | PD5            |
| Servo Control   | PD6            |

## System Operation

### 1. Initial Setup

After reset, the LCD requests the initial parking capacity.

The user enters a number between **1 and 99** using the keypad.

* `0–9` → Enter digits
* `*` → Clear the entered value
* `#` → Confirm the capacity

For example:

```text
SET CAPACITY:
20
```

After confirmation, the number of free spaces is initialized to the selected capacity.

### 2. Vehicle Entry

A HIGH pulse on **PD2** represents an incoming vehicle.

The system checks the number of available spaces:

#### Parking available

If at least one space is available:

1. Green LED turns ON.
2. LCD displays `ENTRY ALLOWED`.
3. Servo gate opens.
4. The available-space counter decreases by one.
5. Servo gate closes.
6. The system returns to the main status screen.

#### Parking full

If no space is available:

1. Red LED turns ON.
2. Buzzer is activated.
3. LCD displays `PARKING FULL`.
4. Entry is rejected.

### 3. Vehicle Exit

The exit button is connected to **PD3** and uses an active-LOW configuration.

When the button is pressed:

1. The free-space counter increases by one.
2. The LCD displays the exit status.
3. The system returns to the main screen.

The counter is protected from exceeding the initial parking capacity.

### 4. Demonstration Mode

For easier demonstration in Proteus, the keypad can also simulate vehicle events after the initial capacity setup:

* `#` → Simulate vehicle entry
* `*` → Simulate vehicle exit

This allows the system to be demonstrated without manually triggering the external pulse input.

## LCD Display Examples

Normal operation:

```text
SMART PARKING
FREE: 15
```

Vehicle entry:

```text
ENTRY ALLOWED
GATE OPEN
```

Parking full:

```text
PARKING FULL
NO ENTRY
```

Vehicle exit:

```text
CAR EXIT
FREE: 16
```

## Servo Control

The servo is controlled through **PD6** using a software-generated PWM signal.

The current configuration uses:

* Approximately **1 ms pulse** → Gate closed
* Approximately **2 ms pulse** → Gate open
* Approximately **20 ms period**

The servo is driven for multiple cycles to provide a stable position in the Proteus simulation.

## Software

### Development Environment

* **Atmel Studio 7**
* **Proteus**

### Microcontroller

**ATmega328P**

Clock frequency:

```text
16 MHz
```


## Building the Project

1. Open the project in **Atmel Studio 7**.
2. Select the **ATmega328P** microcontroller.
3. Set the clock frequency to **16 MHz**.
4. Build the AVR Assembly project.
5. Generate the HEX output.
6. Load the generated `.hex` file into the ATmega328P component in Proteus.
7. Run the Proteus simulation.

## Notes

This version is designed as a **stable presentation/demo build**. The vehicle detector is represented by a digital pulse input rather than measuring the actual pulse width.

The main goal is to demonstrate the complete parking-system logic, including:

```text
Capacity Setup
      ↓
Vehicle Detection
      ↓
Check Available Space
      ↓
 ┌───────────────┐
 │ Space > 0 ?   │
 └───────┬───────┘
         │
    ┌────┴────┐
   YES        NO
    ↓          ↓
Open Gate   Reject Entry
    ↓          ↓
Decrease     Buzzer
Counter      + Red LED
    ↓
Close Gate
    ↓
Update LCD
```

