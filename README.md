# HCS12 Assembly Alarm Clock

An interrupt-driven alarm clock implemented in **HCS12 assembly** for the **Dragon12-Light development board** as the final project for **EGEE 250** at Lake Superior State University.

The system maintains real-time hours, minutes, and seconds, supports a configurable alarm with snooze functionality, accepts user input through a matrix keypad and hardware push buttons, and displays information using both a character LCD and four-digit seven-segment display.

## Features

- Real-time clock implemented using hardware timer interrupts
- Configurable alarm with enable/disable control
- 60-second snooze functionality
- Day-of-week tracking
- Matrix keypad input
- Interrupt-driven hardware push-button controls
- Character LCD interface
- Multiplexed four-digit seven-segment display
- 12-hour LCD display with AM/PM indication
- User-configurable current time and alarm time
- Custom ASCII-to-binary and binary-to-ASCII conversion routines
- Direct register, stack, memory, and peripheral manipulation in HCS12 assembly

## System Overview

The project runs on the **MC9S12/Dragon12-Light platform** and integrates several hardware peripherals into a single assembly application.

```text
              ┌──────────────────┐
              │   Matrix Keypad  │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │      HCS12       │
              │                  │
              │  Clock Logic     │
              │  Alarm / Snooze  │
              │  ECT Interrupts  │
              │  Input Handling  │
              │  Data Conversion │
              └────┬────────┬────┘
                   │        │
           ┌───────┘        └────────┐
           ▼                         ▼
   ┌───────────────┐         ┌────────────────┐
   │ Character LCD │         │ 4-Digit 7-Seg  │
   │  HH:MM:SS     │         │     HH:MM      │
   │ AM/PM + Day   │         │                │
   └───────────────┘         └────────────────┘
                   ▲
                   │
          ┌────────┴─────────┐
          │ Hardware Buttons │
          │ Alarm Controls   │
          └──────────────────┘
```

## Interrupt-Driven Timekeeping

Clock timing is handled using the **Enhanced Capture Timer (ECT)** and output-compare channel 7.

A periodic timer interrupt is counted to produce one-second intervals. Each second, the interrupt service routine handles several system tasks:

1. Increment the current time.
2. Handle seconds, minutes, hours, and day rollover.
3. Check whether the current time matches the configured alarm.
4. Update the snooze countdown when active.
5. Trigger the alarm when necessary.
6. Update the seven-segment display.
7. Toggle the seven-segment display's colon.
8. Update the LCD when appropriate.

This allows the clock and alarm logic to continue operating independently of the main keypad-input loop.

## Alarm and Snooze System

The user can configure an alarm time using the matrix keypad and independently enable or disable the alarm.

When alarms are enabled, the system compares the current hours, minutes, and seconds against the stored alarm time once per second. When all three values match, the alarm state is activated and the LCD changes to an alarm screen.

The alarm can then be either dismissed or snoozed.

Snoozing starts a **60-second countdown**. Once the countdown expires, the alarm is triggered again as long as alarms remain enabled.

A compact flag register is used to track several alarm-related system states, including:

- Alarm-time display mode
- Alarm enabled/disabled
- Alarm active
- Snooze active

## User Input

### Matrix Keypad

A matrix keypad connected through **PORTA** provides the primary user interface.

The keypad scanning routine drives individual columns, detects the active row, and converts the resulting row/column position into its corresponding character.

The keypad is used to:

- Enter the current time
- Enter the alarm time
- Correct input using backspace
- Display the configured alarm time
- Snooze an active alarm
- Dismiss an active alarm
- Enable or disable the alarm

Time values are entered as six digits:

```text
HHMMSS
```

### Hardware Push Buttons

Three hardware push buttons connected through **Port H** provide additional alarm controls.

Button presses are handled using a dedicated interrupt service routine rather than polling. Depending on the button pressed, the user can:

- Snooze an active alarm
- Dismiss an active alarm
- Toggle alarm enable/disable

This provides a second physical interface for controlling the alarm independently of the keypad.

## Time and Day Handling

The clock internally stores hours, minutes, and seconds as separate binary values.

Time rollover is handled directly in assembly:

```text
60 seconds → increment minute
60 minutes → increment hour
24 hours   → return to 00:00:00 and advance day
```

The current day of the week is also tracked. The user selects the initial day when configuring the clock, and the day automatically advances when the clock passes midnight.

The LCD converts the internally stored 24-hour time into a **12-hour representation with AM/PM indication**.

## Data Conversion

Because keypad input and LCD output use ASCII characters while time values are stored numerically, the project implements custom conversion routines directly in assembly.

### ASCII to Binary

Pairs of ASCII characters entered by the user are converted into binary values for hours, minutes, and seconds.

```text
"12" → 12
"34" → 34
"56" → 56
```

### Binary to ASCII

Binary time values are converted back into ASCII characters before being inserted into the LCD output strings.

These routines perform the required arithmetic directly using HCS12 registers and instructions.

## Displays

### Character LCD

The character LCD serves as the primary user interface.

During normal operation it displays the current time, AM/PM state, and current day. It is also used to:

- Prompt for the current time
- Prompt for the alarm time
- Display the configured alarm time
- Display the active alarm screen

### Seven-Segment Display

The Dragon12-Light's four-digit seven-segment display continuously shows the current **hours and minutes**.

```text
12:34
```

The colon is toggled periodically by the clock logic to provide a visible indication that the clock is running.

The display itself is multiplexed using a Real-Time Interrupt (RTI) routine contained in the provided LED display driver.

## Software Structure

The main application is divided into assembly subroutines responsible for individual pieces of the system.

Important routines include:

| Routine | Purpose |
| --- | --- |
| `ECT_INIT` | Configures the output-compare timer interrupt |
| `OC7_ISR` | Handles once-per-second clock, alarm, snooze, and display updates |
| `PTH_INIT` | Configures Port H push-button interrupts |
| `button_press` | Handles interrupt-driven alarm controls |
| `INPUT_CURR_TIME` | Accepts and initializes the current time |
| `INC_TIME` | Updates time and handles rollovers |
| `ALARM` | Compares current and alarm times |
| `GETKEY` | Scans the matrix keypad |
| `P_USER` | Accepts time input from the keypad |
| `V_TIME` | Normalizes entered time values |
| `ascii_to_bin` | Converts ASCII input into numeric values |
| `bin_to_ascii` | Converts numeric values for LCD output |
| `UPDATE_7_SEGs` | Updates seven-segment display values |
| `TOGGLE_A` | Enables or disables the alarm |
| `GET_DAY` / `UPDATE_DAY` | Initializes and advances the day of the week |

## Repository Structure

```text
HCS12_Alarm_Clock/
│
├── README.md
│
├── src/
│   └── alarm_clock.asm
│
└── provided/
    ├── LCD_Driver.asm
    └── LED_Display.asm
```

### `src/alarm_clock.asm`

Contains the student-developed application logic, including:

- Program initialization
- Timer configuration
- Interrupt service routines
- Clock and day tracking
- Alarm and snooze state management
- Keypad scanning and input handling
- Hardware push-button controls
- LCD output formatting
- Seven-segment display updates
- ASCII/binary conversion routines

### `provided/`

Contains display support code supplied for use in EGEE 250.

These files are retained with their original attribution and separated from the student-developed application code to clearly distinguish provided support code from the project implementation.

## Technologies & Concepts

- HCS12 Assembly
- MC9S12 Microcontroller
- Dragon12-Light Development Board
- Enhanced Capture Timer (ECT)
- Output Compare Interrupts
- Real-Time Interrupts (RTI)
- GPIO / Port Interrupts
- Matrix Keypad Scanning
- Character LCD
- Multiplexed Seven-Segment Displays
- Memory-Mapped I/O
- Register-Level Programming
- Interrupt Service Routines
- Stack Operations
- Assembly Subroutines
- State and Flag Management

## Course Context

This project was completed for **EGEE 250** at **Lake Superior State University** during Fall 2025.

**Student developers:**
- Dylan Bollone
- Nick Wingling

The `LCD_Driver.asm` and `LED_Display.asm` support files were provided by **Andrew Jones** for course use. Their original attribution is preserved in the repository.
