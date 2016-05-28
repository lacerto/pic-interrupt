; Copyright (C) 2016 Lacerto <ladislaus@zoho.com>
; This program is free software. It comes without any warranty, to
; the extent permitted by applicable law. You can redistribute it
; and/or modify it under the terms of the Do What The Fuck You Want
; To Public License, Version 2, as published by Sam Hocevar. See
; http://www.wtfpl.net/ and the COPYING file for more details.

#include "p16F690.inc"

; CONFIG -----------------------------------------------------------------------

; __config 0xF0D5
 __CONFIG _FOSC_INTRCCLK & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF

; Constants --------------------------------------------------------------------

MainDelay   equ 0x03                ; delay value in the main loop
IntDelay    equ 0x01                ; delay value in the interrupt handler

; Variables --------------------------------------------------------------------

    UDATA           0x20
Direction       res 1               ; flow direction
Display         res 1               ; value to display using the LEDs
DelayCounter1   res 1               ; delay loop counters
DelayCounter2   res 1
DelayCounter3   res 1
Counter         res 1               ; flash counter
W_Save          res 1               ; W backup
STATUS_Save     res 1               ; STATUS backup
DC_Save1        res 1               ; delay counter backups
DC_Save2        res 1
DC_Save3        res 1

; Macros -----------------------------------------------------------------------

; Saves the context
save_context    macro   reg, save_reg, count
    movwf   W_Save                  ; save W & STATUS + counters
    movf    STATUS, w
    movwf   STATUS_Save

    ; Save a number of key registers having common name prefixes
    local i = 1
    while i <= count
        movf    reg#v(i), w
        movwf   save_reg#v(i)
        i += 1
    endw
    endm

; Restores the context
restore_context macro   reg, save_reg, count
    ; Restore key registers
    local i = 1
    while i <= count
        movf    save_reg#v(i), w
        movwf   reg#v(i)
        i += 1
    endw

    movf    STATUS_Save, w          ; restore W & STATUS
    movwf   STATUS
    swapf   W_Save, f               ; use swapf to restore W
    swapf   W_Save, w               ; as swapf does not affect STATUS
    endm

; Read a byte from program memory and store it in a register
read_prgmem     macro   data_location, reg
    banksel EEADR
    movlw   high data_location
    movwf   EEADRH
    movlw   low data_location
    movwf   EEADR
    banksel EECON1
    bsf     EECON1, EEPGD
    bsf     EECON1, RD
    nop
    nop
    banksel EEDAT
    movf    EEDAT, w
    banksel reg
    movwf   reg
    banksel 0x00
    endm

; RESET VECTOR -----------------------------------------------------------------

RES_VECT  CODE      0x0000          ; processor reset vector
    pagesel START                   ; go to beginning of program
    goto    START

; INTERRUPT HANDLER ------------------------------------------------------------

INT_HANDLER CODE    0x0004          ; 0x0004 - interrupt vector
    save_context    DelayCounter, DC_Save, 3

    read_prgmem RepeatValue, Counter ; init counter with repeat value

FlashLoop:
    movlw   0x0f                    ; RC0-RC3 high
    movwf   PORTC
    movlw   IntDelay                ; delay value -> W
    call    DELAY                   ; call delay subroutine
    clrw                            ; clear W
    movwf   PORTC                   ; RC0-RC3 low
    movlw   IntDelay
    call    DELAY
    decfsz  Counter, f              ; decrement counter
    goto    FlashLoop               ;   not zero? loop

    movf    PORTA, w                ; read PORTA to end mismatch condition
    bcf     INTCON, RABIF           ; clear RABIF flag (interrupt served)
                                    ; see PIC16F690 doc. chapter 4.2.3

    restore_context DelayCounter, DC_Save, 3

    retfie                          ; return from interrupt

; MAIN PROG --------------------------------------------------------------------

MAIN_PROG   CODE
START
    banksel TRISC
    movlw   0xf0                    ; set RC0-RC3 as outputs
    andwf   TRISC, f

    bsf     IOCA, IOCA3             ; RA3 interrupt on change enabled

    banksel PORTA
    movf    PORTA, w                ; read PORTA to avoid mismatch condition
    bcf     INTCON, RABIF           ; clear PORTA/PORTB change interrupt flag

    bsf     INTCON, RABIE           ; enable change interrupt
    bsf     INTCON, GIE             ; enable interrupts

    clrf    Direction               ; init direction (0: rotate right; 1: rlf)

    movlw   0x08                    ; init display (sets RC3 high)
    movwf   Display

MainLoop:
    movf    Display, w              ; Display -> PORTC
    movwf   PORTC

    movlw   MainDelay               ; delay
    call    DELAY

    btfsc   Direction, 0            ; Direction == 0?
    goto    RotateLeft              ;   no - rotate left

RotateRight:                        ;   yes - rotate right
    bcf     STATUS, C               ; clear carry bit
    rrf     Display, f              ; rotate Display bits right
    btfss   STATUS, C               ; is carry clear?
    goto    MainLoop                ;   yes - repeat
    bsf     Direction, 0            ;   no - set direction to 1
    movlw   0x02                    ;        2 -> Display
    movwf   Display
    goto    MainLoop

RotateLeft:
    bcf     STATUS, C               ; clear carry bit
    rlf     Display, f              ; rotate Display bits left
    btfss   Display, 4              ; did it overflow? (we only have 4 LEDS)
    goto    MainLoop                ;   no - repeat
    bcf     Direction, 0            ;   yes - set direction to 0
    movlw   0x04                    ;         4 -> Display
    movwf   Display
    goto    MainLoop

; Subroutines ------------------------------------------------------------------

DELAY
    movwf   DelayCounter3       ; W -> DelayCounter3
    clrf    DelayCounter1       ; ~ 0.2s * W
    clrf    DelayCounter2
Loop:
    decfsz  DelayCounter1, f    ; 3*256 = 768 instruction cycles
    goto    Loop
    decfsz  DelayCounter2, f    ; (768+3)*256 = 197376 instruction cycles
    goto    Loop
    decfsz  DelayCounter3, f    ; (197376+3)*W instruction cycles
    goto    Loop                ; @4MhZ internal clock -> 197379 * W ms delay
    return

; Data -------------------------------------------------------------------------

RepeatValue db 0x00, 0x05       ; number of blinks during interrupt

    END