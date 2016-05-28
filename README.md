# PIC Interrupt Demo

Using the PORTA change interrupt on a PIC16F690. This one sits in the [PICKit2 Low Pin Count Demo Board](http://ww1.microchip.com/downloads/en/DeviceDoc/Low%20Pin%20Count%20User%20Guide%2051556a.pdf).

This project helped me learn how to use:
  * interrupts
  * delays
  * subroutines
  * memory reserving directives
  * macros

## Hardware setup

The demo board is connected to the PICKit2. No wiring.

The four LEDs are controlled by the RC0-RC3 pins and the push button is connected to RA3.

## Function

The program lights the four LEDs of the demo board in succession from left to right changing direction after the last LED on either side has been lit.

A change interrupt for the RA3 pin of PORTA is enabled, thus when the button is pressed the interrupt handler takes over and blinks all four LEDs three times. After the interrupt has been handled the blinking from left to right and vice versa continues where it left off.

## Usage

Compile with [MPASM](http://www.microchip.com/developmenttools/getting_started/gs_mplab2.aspx) or [gpasm](http://gputils.sourceforge.net/) (latter not tested) and program the PIC16F690 with the resulting HEX file.

