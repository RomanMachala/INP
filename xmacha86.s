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

daddi r5, r0, 0                 ; nahrajeme si do registru r5 i
daddi r7, r0, 18                ; do registru r7 dame N (velikost pole)
daddi r8, r0, 17                ; do registru r8 dame N-1
daddi r3, r0, login


outer_loop:
        daddi r6, r0, -1        ; pri kazdem novem cyklu, se resetuje j
        daddi r5, r5, 1         ; inkrementujeme i (start na 1)
        bne r5, r7, inner_loop  ; porovname i a N, pokud je i < N pokracujeme v loopu
        b end
reset:
        daddi r3, r3, -18
        b outer_loop
inner_loop:
        daddi r6, r6, 1         ; inkrementace j
        beq r6, r8, reset       ; konec vnitrniho loopu
        lb r10, 0(r3)           ; nacteme a[j] znak
        lb r11, 1(r3)           ; nacteme a[j + 1] znak
        slt r9, r10, r11        ; porovname mezi sebou
        bnez r9, not_swap       ; pokud je a[j] < a[j+1]
        sb r10, 1(r3)           ; swap
        sb r11, 0(r3)
        daddi r3, r3, 1         ; inkrementace

not_swap:
        daddi r3, r3, 1         ; inkrementace
        b inner_loop

end:
        dadd r4, r0, r3
        jal print_string

        syscall 0               ;halt

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
