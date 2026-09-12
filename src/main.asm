;
; ============================================================
; SMART PARKING SYSTEM - STABLE PRESENTATION BUILD
; MCU      : ATmega328P
; Language : AVR Assembly (AVRASM2 / Atmel Studio 7)
; Clock    : 16 MHz
;
; Final functions:
; - 16x2 LCD in 4-bit mode
; - Initial capacity setting by 4x3 keypad (1..99)
; - Vehicle entry by pulse on PD2
; - Manual/demo entry by # after setup
; - Vehicle exit by push button on PD3
; - Manual/demo exit by * after setup
; - Free-space counter with upper/lower bounds
; - Servo gate control on PD6
; - Green LED, red LED and buzzer status
;
; IMPORTANT PIN MAP:
; LCD: PB0=RS, PB1=E, PB2=D4, PB3=D5, PB4=D6, PB5=D7
; Keypad rows A..D: PC0..PC3
; Keypad cols 1,2,3: PC4, PC5, PD7
; PD0=Buzzer, PD1=Red LED, PD2=Car Pulse, PD3=Exit Button
; PD5=Green LED, PD6=Servo CTRL
; ============================================================
;

.include "m328pdef.inc"

; ============================================================
; PIN DEFINITIONS
; ============================================================

.equ LCD_RS          = 0          ; PB0
.equ LCD_E           = 1          ; PB1

.equ BUZZER_PIN      = 0          ; PD0
.equ RED_LED_PIN     = 1          ; PD1
.equ CAR_PULSE_PIN   = 2          ; PD2
.equ EXIT_BTN_PIN    = 3          ; PD3
.equ GREEN_LED_PIN   = 5          ; PD5
.equ SERVO_PIN       = 6          ; PD6

; ============================================================
; SRAM VARIABLES
; ============================================================

.dseg
.org SRAM_START

total_capacity:
    .byte 1

free_slots:
    .byte 1

car_latch:
    .byte 1

exit_latch:
    .byte 1

; ============================================================
; PROGRAM MEMORY / RESET VECTOR
; ============================================================

.cseg
.org 0x0000
    rjmp RESET

; ============================================================
; RESET / STARTUP
; ============================================================

RESET:
    cli

    ; Stack pointer
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    rcall IO_INIT

    clr r16
    sts total_capacity, r16
    sts free_slots, r16
    sts car_latch, r16
    sts exit_latch, r16

    rcall LCD_INIT

    ; Safe initial outputs
    cbi PORTD, BUZZER_PIN
    cbi PORTD, RED_LED_PIN
    cbi PORTD, GREEN_LED_PIN
    cbi PORTD, SERVO_PIN

    ; Put the gate in the closed position
    rcall SERVO_CLOSE

    ; Ask for the initial capacity
    rcall SET_CAPACITY_FROM_KEYPAD

    ; Ignore a pulse that is already HIGH when setup finishes.
    clr r16
    sbis PIND, CAR_PULSE_PIN
    rjmp RESET_SAVE_CAR_LATCH
    ldi r16, 1
RESET_SAVE_CAR_LATCH:
    sts car_latch, r16

    clr r16
    sts exit_latch, r16

    rcall UPDATE_STATUS_OUTPUTS
    rcall SHOW_MAIN_SCREEN

; ============================================================
; MAIN LOOP
; ============================================================

MAIN_LOOP:
    rcall CHECK_CAR_INPUT
    rcall CHECK_EXIT_BUTTON
    rcall CHECK_DEMO_KEYS
    rjmp MAIN_LOOP

; ============================================================
; I/O INITIALIZATION
; ============================================================

IO_INIT:
    ; PORTB: PB0..PB5 are LCD outputs
    ldi r16, 0b00111111
    out DDRB, r16
    clr r16
    out PORTB, r16

    ; PORTC:
    ; PC0..PC3 keypad rows = outputs
    ; PC4..PC5 keypad columns = inputs with pull-ups
    ldi r16, 0b00001111
    out DDRC, r16
    ldi r16, 0b00111111
    out PORTC, r16

    ; PORTD:
    ; PD0 buzzer output
    ; PD1 red LED output
    ; PD2 car pulse input
    ; PD3 exit button input with pull-up
    ; PD4 unused input
    ; PD5 green LED output
    ; PD6 servo output
    ; PD7 keypad column input with pull-up
    ldi r16, 0b01100011
    out DDRD, r16
    ldi r16, 0b10001000
    out PORTD, r16
    ret

; ============================================================
; CAPACITY SETUP
; 0..9 = digits, # = confirm, * = clear
; Valid range: 1..99
; ============================================================

SET_CAPACITY_FROM_KEYPAD:
    clr r20                    ; entered number
    clr r23                    ; digit count

    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS

    ldi ZL, LOW(2 * MSG_SET_CAPACITY)
    ldi ZH, HIGH(2 * MSG_SET_CAPACITY)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD

CAPACITY_INPUT_LOOP:
    rcall KEYPAD_GET_KEY
    tst r16
    breq CAPACITY_INPUT_LOOP

    cpi r16, '#'
    breq CAPACITY_CONFIRM

    cpi r16, '*'
    breq CAPACITY_CLEAR

    cpi r16, '0'
    brlo CAPACITY_INPUT_LOOP
    cpi r16, '9' + 1
    brsh CAPACITY_INPUT_LOOP

    subi r16, '0'
    mov r21, r16

    tst r23
    breq CAPACITY_FIRST_DIGIT

    cpi r23, 1
    breq CAPACITY_SECOND_DIGIT

    ; Maximum two digits
    rjmp CAPACITY_INPUT_LOOP

CAPACITY_FIRST_DIGIT:
    mov r20, r21
    ldi r23, 1
    rjmp CAPACITY_SHOW_VALUE

CAPACITY_SECOND_DIGIT:
    ; r20 = r20 * 10 + r21
    mov r22, r20
    lsl r20                    ; x2
    lsl r20                    ; x4
    add r20, r22               ; x5
    lsl r20                    ; x10
    add r20, r21
    ldi r23, 2

CAPACITY_SHOW_VALUE:
    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_LCD_SPACES)
    ldi ZH, HIGH(2 * MSG_LCD_SPACES)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD
    mov r16, r20
    rcall LCD_PRINT_NUMBER
    rjmp CAPACITY_INPUT_LOOP

CAPACITY_CLEAR:
    clr r20
    clr r23

    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_LCD_SPACES)
    ldi ZH, HIGH(2 * MSG_LCD_SPACES)
    rcall LCD_PRINT_STRING
    ldi r16, 0xC0
    rcall LCD_CMD
    rjmp CAPACITY_INPUT_LOOP

CAPACITY_CONFIRM:
    tst r20
    breq CAPACITY_INPUT_LOOP

    sts total_capacity, r20
    sts free_slots, r20
    ret

; ============================================================
; KEYPAD SCANNER
; Rows A,B,C,D -> PC0,PC1,PC2,PC3
; Columns 1,2,3 -> PC4,PC5,PD7
; Return: r16 = ASCII key, or 0 when no key is pressed
; ============================================================

KEYPAD_GET_KEY:
    ; Row A low
    ldi r17, 0b00111110
    out PORTC, r17
    rcall KEYPAD_SMALL_DELAY
    sbis PINC, 4
    rjmp KEY_A1
    sbis PINC, 5
    rjmp KEY_A2
    sbis PIND, 7
    rjmp KEY_A3

    ; Row B low
    ldi r17, 0b00111101
    out PORTC, r17
    rcall KEYPAD_SMALL_DELAY
    sbis PINC, 4
    rjmp KEY_B1
    sbis PINC, 5
    rjmp KEY_B2
    sbis PIND, 7
    rjmp KEY_B3

    ; Row C low
    ldi r17, 0b00111011
    out PORTC, r17
    rcall KEYPAD_SMALL_DELAY
    sbis PINC, 4
    rjmp KEY_C1
    sbis PINC, 5
    rjmp KEY_C2
    sbis PIND, 7
    rjmp KEY_C3

    ; Row D low
    ldi r17, 0b00110111
    out PORTC, r17
    rcall KEYPAD_SMALL_DELAY
    sbis PINC, 4
    rjmp KEY_D1
    sbis PINC, 5
    rjmp KEY_D2
    sbis PIND, 7
    rjmp KEY_D3

    clr r16
    ldi r17, 0b00111111
    out PORTC, r17
    ret

KEY_A1:
    ldi r16, '1'
    rjmp KEYPAD_KEY_FOUND
KEY_A2:
    ldi r16, '2'
    rjmp KEYPAD_KEY_FOUND
KEY_A3:
    ldi r16, '3'
    rjmp KEYPAD_KEY_FOUND
KEY_B1:
    ldi r16, '4'
    rjmp KEYPAD_KEY_FOUND
KEY_B2:
    ldi r16, '5'
    rjmp KEYPAD_KEY_FOUND
KEY_B3:
    ldi r16, '6'
    rjmp KEYPAD_KEY_FOUND
KEY_C1:
    ldi r16, '7'
    rjmp KEYPAD_KEY_FOUND
KEY_C2:
    ldi r16, '8'
    rjmp KEYPAD_KEY_FOUND
KEY_C3:
    ldi r16, '9'
    rjmp KEYPAD_KEY_FOUND
KEY_D1:
    ldi r16, '*'
    rjmp KEYPAD_KEY_FOUND
KEY_D2:
    ldi r16, '0'
    rjmp KEYPAD_KEY_FOUND
KEY_D3:
    ldi r16, '#'

KEYPAD_KEY_FOUND:
    ; Debounce while preserving the key
    push r16
    ldi r16, 20
    rcall DELAY_MS
    pop r16
    push r16

KEYPAD_WAIT_RELEASE:
    ; All rows low, then wait for all columns to return high
    ldi r17, 0b00110000
    out PORTC, r17
    rcall KEYPAD_SMALL_DELAY
    sbis PINC, 4
    rjmp KEYPAD_WAIT_RELEASE
    sbis PINC, 5
    rjmp KEYPAD_WAIT_RELEASE
    sbis PIND, 7
    rjmp KEYPAD_WAIT_RELEASE

    ldi r17, 0b00111111
    out PORTC, r17
    pop r16
    ret

KEYPAD_SMALL_DELAY:
    push r18
    ldi r18, 50
KEYPAD_SMALL_DELAY_LOOP:
    dec r18
    brne KEYPAD_SMALL_DELAY_LOOP
    pop r18
    ret

; ============================================================
; VEHICLE ENTRY INPUT
; A HIGH pulse on PD2 counts as one incoming car.
; Pulse width measurement was intentionally removed for a
; stable Proteus presentation. The pulse generator is the
; simulated equivalent of the ultrasonic detector.
; ============================================================

CHECK_CAR_INPUT:
    ; LOW -> arm the next event
    sbis PIND, CAR_PULSE_PIN
    rjmp CAR_INPUT_LOW

    ; HIGH -> handle only once
    lds r16, car_latch
    tst r16
    brne CAR_INPUT_DONE

    ldi r16, 1
    sts car_latch, r16
    rcall HANDLE_CAR_ENTRY
    ret

CAR_INPUT_LOW:
    clr r16
    sts car_latch, r16

CAR_INPUT_DONE:
    ret

; ============================================================
; EXIT BUTTON ON PD3 (active LOW, internal pull-up)
; ============================================================

CHECK_EXIT_BUTTON:
    ; Released HIGH -> arm next press
    sbis PIND, EXIT_BTN_PIN
    rjmp EXIT_BUTTON_PRESSED

    clr r16
    sts exit_latch, r16
    ret

EXIT_BUTTON_PRESSED:
    lds r16, exit_latch
    tst r16
    brne EXIT_BUTTON_DONE

    ldi r16, 20
    rcall DELAY_MS

    ; If it is no longer LOW, it was only bounce
    sbic PIND, EXIT_BTN_PIN
    rjmp EXIT_BUTTON_DONE

    ldi r16, 1
    sts exit_latch, r16
    rcall HANDLE_CAR_EXIT

EXIT_BUTTON_DONE:
    ret

; ============================================================
; DEMONSTRATION FALLBACK CONTROLS
; After capacity setup:
; # = simulate an incoming car
; * = simulate an outgoing car
; This makes the project presentable even if an external
; generator/button wire is not clicked during the demo.
; ============================================================

CHECK_DEMO_KEYS:
    rcall KEYPAD_GET_KEY
    tst r16
    breq DEMO_KEYS_DONE

    cpi r16, '#'
    breq DEMO_MANUAL_ENTRY

    cpi r16, '*'
    breq DEMO_MANUAL_EXIT

    rjmp DEMO_KEYS_DONE

DEMO_MANUAL_ENTRY:
    rcall HANDLE_CAR_ENTRY
    rjmp DEMO_KEYS_DONE

DEMO_MANUAL_EXIT:
    rcall HANDLE_CAR_EXIT

DEMO_KEYS_DONE:
    ret

; ============================================================
; ENTRY HANDLER
; ============================================================

HANDLE_CAR_ENTRY:
    lds r16, free_slots
    tst r16
    breq HANDLE_PARKING_FULL

    cbi PORTD, RED_LED_PIN
    cbi PORTD, BUZZER_PIN
    sbi PORTD, GREEN_LED_PIN

    rcall SHOW_ENTRY_SCREEN
    rcall SERVO_OPEN
    rcall DELAY_500MS

    lds r16, free_slots
    dec r16
    sts free_slots, r16

    rcall SERVO_CLOSE
    cbi PORTD, GREEN_LED_PIN
    rcall UPDATE_STATUS_OUTPUTS
    rcall SHOW_MAIN_SCREEN
    ret

HANDLE_PARKING_FULL:
    cbi PORTD, GREEN_LED_PIN
    sbi PORTD, RED_LED_PIN
    sbi PORTD, BUZZER_PIN

    rcall SHOW_FULL_SCREEN
    rcall DELAY_500MS
    cbi PORTD, BUZZER_PIN
    rcall DELAY_500MS

    rcall UPDATE_STATUS_OUTPUTS
    rcall SHOW_MAIN_SCREEN
    ret

; ============================================================
; EXIT HANDLER
; ============================================================

HANDLE_CAR_EXIT:
    lds r16, free_slots
    lds r17, total_capacity

    ; Do not exceed the initial capacity
    cp r16, r17
    brsh CAR_EXIT_DONE

    inc r16
    sts free_slots, r16

    rcall UPDATE_STATUS_OUTPUTS
    rcall SHOW_EXIT_SCREEN
    rcall DELAY_500MS
    rcall SHOW_MAIN_SCREEN

CAR_EXIT_DONE:
    ret

; ============================================================
; NORMAL STATUS OUTPUTS
; Red LED is ON only when FREE=0.
; Green LED is ON only during an allowed entry.
; Buzzer is normally OFF.
; ============================================================

UPDATE_STATUS_OUTPUTS:
    cbi PORTD, GREEN_LED_PIN
    cbi PORTD, BUZZER_PIN

    lds r16, free_slots
    tst r16
    breq STATUS_FULL

    cbi PORTD, RED_LED_PIN
    ret

STATUS_FULL:
    sbi PORTD, RED_LED_PIN
    ret

; ============================================================
; SERVO CONTROL
; Proteus MOTOR-PWMSERVO:
; CTRL -> PD6, VCC -> +5V, GND -> GND
; 1 ms = closed, 2 ms = open
; ============================================================

SERVO_OPEN:
    push r16
    push r24
    ldi r24, 20
SERVO_OPEN_LOOP:
    sbi PORTD, SERVO_PIN
    ldi r16, 2
    rcall DELAY_MS
    cbi PORTD, SERVO_PIN
    ldi r16, 18
    rcall DELAY_MS
    dec r24
    brne SERVO_OPEN_LOOP
    pop r24
    pop r16
    ret

SERVO_CLOSE:
    push r16
    push r24
    ldi r24, 20
SERVO_CLOSE_LOOP:
    sbi PORTD, SERVO_PIN
    ldi r16, 1
    rcall DELAY_MS
    cbi PORTD, SERVO_PIN
    ldi r16, 19
    rcall DELAY_MS
    dec r24
    brne SERVO_CLOSE_LOOP
    pop r24
    pop r16
    ret

; ============================================================
; LCD 4-BIT DRIVER
; ============================================================

LCD_INIT:
    ldi r16, 20
    rcall DELAY_MS

    cbi PORTB, LCD_RS
    cbi PORTB, LCD_E

    ldi r17, 0x03
    rcall LCD_SEND_NIBBLE
    ldi r16, 5
    rcall DELAY_MS

    ldi r17, 0x03
    rcall LCD_SEND_NIBBLE
    ldi r16, 2
    rcall DELAY_MS

    ldi r17, 0x03
    rcall LCD_SEND_NIBBLE
    ldi r16, 2
    rcall DELAY_MS

    ldi r17, 0x02
    rcall LCD_SEND_NIBBLE
    ldi r16, 2
    rcall DELAY_MS

    ldi r16, 0x28
    rcall LCD_CMD
    ldi r16, 0x0C
    rcall LCD_CMD
    ldi r16, 0x06
    rcall LCD_CMD
    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS
    ret

LCD_CMD:
    cbi PORTB, LCD_RS
    rcall LCD_SEND_BYTE
    ret

LCD_DATA:
    sbi PORTB, LCD_RS
    rcall LCD_SEND_BYTE
    ret

LCD_SEND_BYTE:
    push r16
    push r17

    mov r17, r16
    swap r17
    andi r17, 0x0F
    rcall LCD_SEND_NIBBLE

    mov r17, r16
    andi r17, 0x0F
    rcall LCD_SEND_NIBBLE

    pop r17
    pop r16
    rcall DELAY_1MS
    ret

LCD_SEND_NIBBLE:
    push r17
    push r18

    ; Preserve only RS, replace E and data bits
    in r18, PORTB
    andi r18, 0b00000001

    lsl r17
    lsl r17
    andi r17, 0b00111100
    or r18, r17
    out PORTB, r18

    sbi PORTB, LCD_E
    nop
    nop
    nop
    cbi PORTB, LCD_E

    pop r18
    pop r17
    ret

LCD_PRINT_STRING:
LCD_PRINT_LOOP:
    lpm r16, Z+
    tst r16
    breq LCD_PRINT_DONE
    rcall LCD_DATA
    rjmp LCD_PRINT_LOOP
LCD_PRINT_DONE:
    ret

LCD_PRINT_NUMBER:
    push r17
    push r18
    push r19

    mov r18, r16
    clr r17

LCD_TENS_LOOP:
    cpi r18, 10
    brlo LCD_TENS_DONE
    subi r18, 10
    inc r17
    rjmp LCD_TENS_LOOP

LCD_TENS_DONE:
    tst r17
    breq LCD_PRINT_ONES
    mov r16, r17
    ldi r19, '0'
    add r16, r19
    rcall LCD_DATA

LCD_PRINT_ONES:
    mov r16, r18
    ldi r19, '0'
    add r16, r19
    rcall LCD_DATA

    pop r19
    pop r18
    pop r17
    ret

; ============================================================
; LCD SCREENS
; ============================================================

SHOW_MAIN_SCREEN:
    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS

    ldi ZL, LOW(2 * MSG_SMART_PARKING)
    ldi ZH, HIGH(2 * MSG_SMART_PARKING)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_FREE)
    ldi ZH, HIGH(2 * MSG_FREE)
    rcall LCD_PRINT_STRING
    lds r16, free_slots
    rcall LCD_PRINT_NUMBER
    ret

SHOW_ENTRY_SCREEN:
    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS

    ldi ZL, LOW(2 * MSG_ENTRY_ALLOWED)
    ldi ZH, HIGH(2 * MSG_ENTRY_ALLOWED)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_GATE_OPEN)
    ldi ZH, HIGH(2 * MSG_GATE_OPEN)
    rcall LCD_PRINT_STRING
    ret

SHOW_FULL_SCREEN:
    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS

    ldi ZL, LOW(2 * MSG_PARKING_FULL)
    ldi ZH, HIGH(2 * MSG_PARKING_FULL)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_NO_ENTRY)
    ldi ZH, HIGH(2 * MSG_NO_ENTRY)
    rcall LCD_PRINT_STRING
    ret

SHOW_EXIT_SCREEN:
    ldi r16, 0x01
    rcall LCD_CMD
    ldi r16, 3
    rcall DELAY_MS

    ldi ZL, LOW(2 * MSG_CAR_EXIT)
    ldi ZH, HIGH(2 * MSG_CAR_EXIT)
    rcall LCD_PRINT_STRING

    ldi r16, 0xC0
    rcall LCD_CMD
    ldi ZL, LOW(2 * MSG_FREE)
    ldi ZH, HIGH(2 * MSG_FREE)
    rcall LCD_PRINT_STRING
    lds r16, free_slots
    rcall LCD_PRINT_NUMBER
    ret

; ============================================================
; DELAYS FOR 16 MHz
; ============================================================

DELAY_1MS:
    push r18
    push r19
    ldi r18, 21
DELAY_1MS_OUTER:
    ldi r19, 255
DELAY_1MS_INNER:
    dec r19
    brne DELAY_1MS_INNER
    dec r18
    brne DELAY_1MS_OUTER
    pop r19
    pop r18
    ret

DELAY_MS:
    push r18
    mov r18, r16
DELAY_MS_LOOP:
    rcall DELAY_1MS
    dec r18
    brne DELAY_MS_LOOP
    pop r18
    ret

DELAY_500MS:
    push r16
    ldi r16, 250
    rcall DELAY_MS
    ldi r16, 250
    rcall DELAY_MS
    pop r16
    ret

; ============================================================
; LCD TEXT - each .db block has even byte length
; ============================================================

MSG_SMART_PARKING:
    .db "SMART PARKING", 0

MSG_FREE:
    .db "FREE: ", 0, 0

MSG_SET_CAPACITY:
    .db "SET CAPACITY:", 0

MSG_ENTRY_ALLOWED:
    .db "ENTRY ALLOWED", 0

MSG_GATE_OPEN:
    .db "GATE OPEN", 0

MSG_PARKING_FULL:
    .db "PARKING FULL", 0, 0

MSG_NO_ENTRY:
    .db "NO ENTRY", 0, 0

MSG_CAR_EXIT:
    .db "CAR EXIT", 0, 0

MSG_LCD_SPACES:
    .db "                ", 0, 0
