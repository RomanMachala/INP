; Autor reseni: Roman Machala xmacha86
; Pocet cyklu k serazeni puvodniho retezce:
; Pocet cyklu razeni sestupne serazeneho retezce:
; Pocet cyklu razeni vzestupne serazeneho retezce:
; Pocet cyklu razeni retezce s vasim loginem:
; Implementovany radici algoritmus: Bubble sort algorithm
; ------------------------------------------------

; DATA SEGMENT
                .data                    
login:          .asciiz "vitejte-v-inp-2023"    ; puvodni uvitaci retezec
; login:          .asciiz "vvttpnjiiee3220---"  ; sestupne serazeny retezec
; login:          .asciiz "---0223eeiijnpttvv"  ; vzestupne serazeny retezec
; login:          .asciiz "xlogin00"            ; SEM DOPLNTE VLASTNI LOGIN
                                                ; A POUZE S TIMTO ODEVZDEJTE

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize - "funkce" print_string)

; CODE SEGMENT
                .text
        daddi r3, r0, login
        lb r7, 0(r3)
        sb r7, 1(r3)
        daddi r3, r3, 2

        lb r7, 0(r3)
        sb r7, 1(r3)
        dadd r4, r0, r3
        jal print_string

        daddi r3, r3, -2
        dadd r4, r0, r3
        jal print_string


        syscall 0               ;halt

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
