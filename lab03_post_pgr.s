/*	
    Archivo:		lab03_post_pgr.s
    Dispositivo:	PIC16F887
    Autor:		Gerardo Paz 20173
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Botones y Timer0 
    Hardware:		7 segmentos en el Puerto C
			Contador timer0 Puerto A
			Contadir segundos Puerto D
			Led de alarma Puerto E

    Creado:			12/02/22
    Última modificación:	12/02/22	
*/

PROCESSOR 16F887
#include <xc.inc>
 
; CONFIG1
CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

    
PSECT udata_bank0		//common memory
  CONT7SEG:		DS  1		// Contador 7 seg
  CONTT0:		DS  1		// Contador Timer 0 (hasta 10)
   
PSECT resVect, class=CODE, abs, delta=2
// -------- Configuración del RESET --------
    
ORG 00h                       // posición 0000h para el reset
    
resVect:
    PAGESEL main
    GOTO    main
    
PSECT code, delta=2, abs
// -------- Configuración del microcontrolador --------
 
ORG 100h //Dirección 100% seguro de que ya pasó el reseteo

 main:
    CALL    setup_io
    CALL    oscilador
    CALL    timer0
    
    BANKSEL PORTB
    
    MOVLW   00111111B	//iniciar 7seg en 0
    MOVWF   PORTC
    
    //Limpiar variables
    CLRF    CONT7SEG
    CLRF    CONTT0
    
 loop:
    BTFSC   PORTB, 0	//Revisar RB0
    CALL    button_inc
    
    BTFSC   PORTB, 1	//Revisar RB1
    CALL    button_dec
    
    CALL    cont_timer0	//Aumentar el contador del timer0 
    CALL    comparar	//Constantemente revisar los contadores
    
    GOTO    loop
    
    
 comparar:
    MOVF    CONT7SEG, 0	//Mover puerto C a W
    SUBWF   PORTD, 0	//Restar C - D
    
    BTFSC   ZERO	//Si la bandera de ZERO está activa, resetear valores
    CALL    reset_igualdad
    
    RETURN
 
 reset_igualdad:
    CLRF    PORTD   //Limpiar segundos
    CLRF    CONTT0  //Limpiar cont Timer0
    INCF    PORTE   //Cambiar estado del led de Alarma
    
    RETURN
    
 cont_timer0:
    BTFSS   T0IF    //Verificar la interrupción
    GOTO $-1
    
    CALL    reset_timer0
    INCF    PORTA
    INCF    CONTT0
    BTFSS   CONTT0, 1	//Cuenta a 2
    RETURN
    BTFSS   CONTT0, 3	// Cuenta los otros 8
    RETURN
    
    INCF    PORTD
    CLRF    CONTT0
    
    RETURN
    
    
 button_inc:
    BTFSC   PORTB, 0	//Revisar button en RB0
    GOTO    $-1
    
    INCF    CONT7SEG	//incrementar A
    MOVF    CONT7SEG, W	//Mover el valor de A 
    CALL    tabla	//La tabla devuelve el valor de A convertido a 7 segmentos
    MOVWF   PORTC	//El valor convertido se va a C
    
    GOTO    loop
    
    
 button_dec:
    BTFSC   PORTB, 1	//Revisar button en RB0
    GOTO    $-1
    
    DECF    CONT7SEG	//incrementar A
    MOVF    CONT7SEG, W	//Mover el valor de A 
    CALL    tabla	//La tabla devuelve el valor de A convertido a 7 segmentos
    MOVWF   PORTC	//El valor convertido se va a C
    
    GOTO    loop
    

 setup_io:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	//  I/O DIGITAL
    
    BANKSEL TRISB
    BSF	    TRISB, 0	//RB0 in
    BSF	    TRISB, 1	//RB1 in
    
    BANKSEL TRISA	
    CLRF    TRISC	//C out cont 7seg
    
    BCF	    TRISE, 0	//RE0 out alarma
    
    //A out cont Timer0
    BCF	    TRISA, 0
    BCF	    TRISA, 1
    BCF	    TRISA, 2
    BCF	    TRISA, 3
    
    //D out cont segundos
    BCF	    TRISD, 0
    BCF	    TRISD, 1
    BCF	    TRISD, 2
    BCF	    TRISD, 3
    
    BANKSEL PORTA
    CLRF    PORTA	//Limpiar puertos
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRF    PORTE
    
    RETURN
    
 timer0:
    // retraso de 100 ms
    // Fosc = 1MHz
    // PS = 256
    // T = 4 * Tosc * TMR0 * PS
    // Tosc = 1/Fosc
    // TMR0 = T * Fosc / (4 * PS) = 256-N
    // N = 256 - (100ms * 1MHz / (4 * 256))
    // N = 158 aprox
    
    BANKSEL OPTION_REG
    
    BCF T0CS	    //Funcionar como temporizador
    BCF PSA	    //Asignar Prescaler al Timer0
    
    //Prescaler de 1:128
    BSF PS2	    // 1
    BSF PS1	    // 0 
    BSF PS0	    // 0
    
    //Asignar los 100ms de retardo
    BANKSEL PORTA
    CALL    reset_timer0
    
    RETURN   
 
    
 reset_timer0: //siempre hay que volver a asignarle el valor al TMR0
    BANKSEL TMR0
    MOVLW   158	    //Cargamos N en W
    MOVWF   TMR0	    //Cargamos N en el TMR0, listo el retardo de 100ms
    
    BCF	T0IF	    //Limpiar bandera de interrupción

    RETURN
    
    
 oscilador:
    BANKSEL OSCCON
    BSF	SCS		//Activar oscilador interno
    
    // 1 MHz
    BSF IRCF2		// 1
    BCF IRCF1		// 0
    BCF IRCF0		// 0
    
    RETURN
    
    
 ORG 200h   
 tabla:
    CLRF    PCLATH
    BSF	    PCLATH, 1	//LATH en posición 1
    
    ANDLW   0x0F	//No sobrepasar el tamaño de la tabla (<16)
    ADDWF   PCL		//PC = PCLATH + PCL 
    
    RETLW   00111111B	//0
    RETLW   00000110B	//1
    RETLW   01011011B	//2
    RETLW   01001111B	//3
    RETLW   01100110B	//4
    RETLW   01101101B	//5
    RETLW   01111101B	//6
    RETLW   00000111B	//7
    RETLW   01111111B	//8
    RETLW   01101111B	//9
    RETLW   01110111B	//A
    RETLW   01111100B	//B
    RETLW   00111001B	//C
    RETLW   01011110B	//D
    RETLW   01111001B	//E
    RETLW   01110001B	//F
    
 END