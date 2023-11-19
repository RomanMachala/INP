; Autor reseni: Roman Machala xmacha86
; Pocet cyklu k serazeni puvodniho retezce: 2 116
; Pocet cyklu razeni sestupne serazeneho retezce: 2 424
; Pocet cyklu razeni vzestupne serazeneho retezce: 349
; Pocet cyklu razeni retezce s vasim loginem: 531
; Implementovany radici algoritmus: Bubble sort 
; ------------------------------------------------

; DATA SEGMENT
                .data   
; login:          .asciiz "vitejte-v-inp-2023"          ; puvodni uvitaci retezec
; login:          .asciiz "vvttpnjiiee3220---"          ; sestupne serazeny retezec
; login:          .asciiz "---0223eeiijnpttvv"          ; vzestupne serazeny retezec                 
login:            .asciiz "xmacha86"                    ; SEM DOPLNTE VLASTNI LOGIN
                                                        ; A POUZE S TIMTO ODEVZDEJTE

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize - "funkce" print_string)

; CODE SEGMENT
                .text
main:
        daddi r6, r0, login     ; do r6 a r4 si ulozime adresu retezce login (r6 potom bude ukazatel na posledni znak retezce a r4 na prvni)
        daddi r4, r0, login   
        lb r7, 0(r6)            ; nacteme jeden znak z adresy danou registrem r6
        daddi r9, r0, 1         ; r9 registr bude 'flag' jestli doslo k zamene nebo ne, ze zacatku musi byt nastaven na 1
        ; kdyby byl retezec jiz usporadany, tak by se zbytecne cyklilo pres cely retezec i bez zameny
    

        

    delka_retezce:
        daddi r6, r6, 1         ;posuneme ukazatel na dalsi prvek
        beq r7, r0, konec_delky_retezce         ; porovname aktualne nacteny znak na konec retezce

        lb r7, 0(r6)                            ; nacteme dalsi znak
        j delka_retezce 
    konec_delky_retezce:
    
        daddi r2, r6, -2                    ; do r2 ulozime aktualne posledni prvek (pred '\0')
                ;musime snizit o 2, protoze jsme implicitne o 1 posunuti dale (-1 bychom dostali znak '\0')


        ;v teto chvili mame v r4 ulozenou adresu prvniho znaku a v r2 adresu posledniho znaku

    vnejsi:
                daddi r3, r4, 0         ; Pred kazdym zanorenim, resetujeme ukazatel na prvni znak v retezci
                beqz r9, end            ; Pokud nedoslo k ani jedne zamene, je retezec usporadany (pri prvnim pruchodu je implicitne nastaven na 1)
                daddi r9, r0, 0         ; reset flagu zameny

                lb r7, 0(r3)            ; Nacteme aktualni prvek        pole[index]
                lb r8, 1(r3)            ; Nacteme aktualni prvek + 1 pole[index + 1]

        vnitrni:
                slt r9, r8, r7          ; Porovname mezi sebou prvek na indexu a index + 1 ------- if r8 < r7 => r9 = 1; else r9 = 0;
                beq r9, r0, bez_zameny  ; Pokud je r9 == 0, neprovadime vymenu (preskocime spodni prohozeni prvku)

                daddi r9, r9, 1         ; doslo k zamene, inkrementace flagu

                sb r8, 0(r3)            ; Samotne prohozeni prvku
                sb r7, 1(r3)

        bez_zameny:
                daddi r3, r3, 1         ; Posun na dalsi 
                lb r7, 0(r3)            ; Nacteme aktualni prvek        pole[index]
                lb r8, 1(r3)            ; Nacteme aktualni prvek + 1 pole[index + 1]
                bne r3, r2, vnitrni     ; Porovname aktualni prvek a ukazatel na konec retezce (pokud nejsme na konci, pokracujeme dale)

                daddi r2, r2, -1        ; pokud se aktualni prvek rovna poslednimu prvku, posuneme posledni prvek o pozici doleva 
                                        ;(pri dalsim pruchodu jiz nemusime pristupivat na posledni prvek, portoze ten ma nejvzssi hodnotu)
                bne r2, r4, vnejsi  ; Opakujeme vnejsi cyklus, dokud ukazatel na posledni prvek nebude roven zacatku reetzce

end:
        jal print_string        ; vypis retezce
        syscall 0  ;halt



print_string:                                   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5                       ; systemova procedura - vypis retezce na terminal
                jr      r31                     ; return - r31 je urcen na return address
