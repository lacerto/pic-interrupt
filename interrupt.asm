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
 
FlashRepeat equ 0x03            ; number of flashes
MainDelay   equ 0x03            ; delay value in the main loop
IntDelay    equ 0x01            ; delay value in the interrupt handler
 
; Variables --------------------------------------------------------------------
    
    cblock 0x20
        Direction                   ; flow direction
        Display                     ; value to display using the LEDs
        DelayCounter1               ; delay loop counters
        DelayCounter2
        DelayCounter3
        Counter                     ; flash counter
        W_Save                      ; W backup
        STATUS_Save                 ; STATUS backup
        DC1_Save                    ; delay counter backups
        DC2_Save
        DC3_Save
    endc		  
    
; RESET VECTOR -----------------------------------------------------------------
    
RES_VECT  CODE    0x0000            ; processor reset vector
    goto    START                   ; go to beginning of program
    nop                             ; 0x0001
    nop                             ; 0x0002
    nop                             ; 0x0003

; INTERRUPT HANDLER ------------------------------------------------------------
    
INT_HANDLER                         ; 0x0004 - interrupt vector
    movwf   W_Save                  ; save W & STATUS + counters
    movf    STATUS, w
    movwf   STATUS_Save
    movf    DelayCounter1, w
    movwf   DC1_Save
    movf    DelayCounter2, w
    movwf   DC2_Save
    movf    DelayCounter3, w
    movwf   DC3_Save
        
    movlw   FlashRepeat             ; init counter with repeat value
    movwf   Counter
    
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
    movf    DC1_Save, w             ; restore counters, STATUS and W
    movwf   DelayCounter1
    movf    DC2_Save, w
    movwf   DelayCounter2
    movf    DC3_Save, w
    movwf   DelayCounter3
    movf    STATUS_Save, w          ; restore W & STATUS
    movwf   STATUS
    swapf   W_Save, f               ; use swapf to restore W
    swapf   W_Save, w               ; as swapf does not affect STATUS
    
    retfie                          ; return from interrupt

; MAIN PROG --------------------------------------------------------------------
    
START
    bcf     STATUS, RP1             ; select bank 1
    bsf     STATUS, RP0
    
    movlw   0xf0                    ; set RC0-RC3 as outputs
    andwf   TRISC, f
    
    bsf     IOCA, IOCA3             ; RA3 interrupt on change enabled
    
    bcf     STATUS, RP0             ; select bank 0

    movf    PORTA, w                ; read PORTA to avoid mismatch condition
    bcf     INTCON, RABIF           ; clear PORTA/PORTB change interrupt flag
    
    bsf     INTCON, RABIE           ; enable change interrupt
    bsf     INTCON, GIE             ; enable interrupts

    clrf   Direction                ; init direction (0: rotate right; 1: rlf)
    
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
    
    END