# HCS12 Assembly Digital Clock

An interrupt-driven digital clock implemented in **HCS12 assembly** for the **Dragon12-Light development board** as the final project for **EGEE 250** at Lake Superior State University.

The system maintains real-time hours, minutes, and seconds, accepts user input through a matrix keypad, and displays the current time using both a character LCD and the board's four-digit seven-segment display.

## Features

- Real-time clock implemented using hardware timer interrupts
- Hours, minutes, and seconds tracking
- 12-hour LCD display with AM/PM indication
- Four-digit seven-segment display for hours and minutes
- Matrix keypad input
- User-configurable starting time
- Input validation and backspace support
- Binary-to-ASCII and ASCII-to-binary conversion routines
- Direct register, stack, and memory manipulation in HCS12 assembly
- LCD and multiplexed seven-segment display integration

## System Overview

The application runs on the **MC9S12/Dragon12-Light platform** and combines several on-board peripherals into a single assembly application.

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
              │  ECT Interrupts  │
              │  Input Handling  │
              │  Data Conversion │
              └───────┬───┬──────┘
                      │   │
              ┌───────┘   └───────┐
              ▼                   ▼
      ┌───────────────┐   ┌────────────────┐
      │ Character LCD │   │ 4-Digit 7-Seg  │
      │  HH:MM:SS     │   │     HH:MM      │
      │     AM/PM     │   │                │
      └───────────────┘   └────────────────┘
```

## Interrupt-Driven Timekeeping

Clock timing is handled using the **Enhanced Capture Timer (ECT)** and output-compare channel 7.

The timer generates periodic interrupts that are counted to produce one-second intervals. Once one second has elapsed, the interrupt service routine:

1. Increments the current time.
2. Handles seconds, minutes, and hour rollover.
3. Updates the four-digit seven-segment display.
4. Updates the character LCD.

This allows timekeeping to operate independently of the program's main input loop.

## Time Handling

The clock internally stores hours, minutes, and seconds as separate binary values.

Time rollover is handled directly in assembly:

```text
60 seconds → increment minute
60 minutes → increment hour
24 hours   → return to 00:00:00
```

The LCD converts the internally stored 24-hour time into a **12-hour representation with AM/PM indication**, including handling midnight and noon transitions.

## Keypad Interface

A matrix keypad connected through **PORTA** provides user input.

The keypad scanning routine:

- Drives individual keypad columns.
- Reads the active row.
- Determines the selected key.
- Converts the row/column position into its corresponding character.

The user can enter a six-digit time in the form:

```text
HHMMSS
```

Input is displayed on the LCD as it is entered, and a backspace function allows the user to correct entries before the time is stored.

## Data Conversion

Because the clock stores time numerically but receives and displays ASCII characters, the project implements custom conversion routines in assembly.

### ASCII to Binary

Pairs of ASCII digits are converted into numeric values for hours, minutes, and seconds.

```text
"12" → 12
"34" → 34
"56" → 56
```

### Binary to ASCII

Binary time values are converted back into ASCII characters before being placed into the LCD output string.

These routines perform the required arithmetic directly using HCS12 registers and instructions.

## Displays

### Character LCD

The LCD displays the complete time in a human-readable format:

```text
  Current Time
  12:34:56 PM
```

The LCD is also used as the interface for entering time values through the keypad.

### Seven-Segment Display

The Dragon12-Light's four-digit seven-segment display shows the current **hours and minutes**.

```text
12:34
```

The display is multiplexed using a Real-Time Interrupt (RTI) routine contained in the provided LED display driver.

## Repository Structure

```text
Assembly_Digital_Clock/
│
├── README.md
│
├── src/
│   └── digital_clock.asm
│
└── provided/
    ├── LCD_Driver.asm
    └── LED_Display.asm
```

### `src/digital_clock.asm`

Main project source code containing the student-developed application logic, including:

- Program initialization
- ECT configuration
- Output-compare interrupt service routine
- Clock and rollover logic
- Keypad scanning
- User input handling
- LCD output formatting
- Seven-segment display updates
- ASCII/binary conversion routines

### `provided/`

Contains display support code supplied for use in EGEE 250.

These files are retained with their original attribution and are separated from the student-developed application code for clarity.

## Technologies & Concepts

- HCS12 Assembly
- MC9S12 Microcontroller
- Dragon12-Light Development Board
- Enhanced Capture Timer (ECT)
- Output Compare Interrupts
- Real-Time Interrupts (RTI)
- Matrix Keypad Scanning
- Character LCD
- Multiplexed Seven-Segment Displays
- Memory-Mapped I/O
- Register-Level Programming
- Stack Operations
- Assembly Subroutines

## Course Context

This project was completed for **EGEE 250** at **Lake Superior State University** during Fall 2025.

**Student developers:**
- Dylan Bollone
- Nick Wingling

The `LCD_Driver.asm` and `LED_Display.asm` support files were provided by **Andrew Jones** for course use. Their original attribution is preserved in the repository.
