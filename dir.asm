; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

; Mode bits:
;   0 - 0=short display
;       1=long display      -l    (shows date and size)
;   1 - 1=show hidden files
;   3 - 1=sort
;   4 - 1=descending        -r
;   5 - sort on size        -s
;   6 - sort on date        -d
;   7 - sort on name        -n

include    ../bios.inc
include    ../kernel.inc

           org     8000h
           lbr     0ff00h
           db      'dir',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0

           org     2000h
           br      start

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

start:     mov     rf,next             ; point to dirents pointer
           mov     r7,dirents          ; dirents storage
           ldi     0                   ; terminate list
           str     r7
           ghi     r7                  ; store pointer
           str     rf
           inc     rf
           glo     r7
           str     rf
           ldi     high crlf           ; display a cr/lf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall
           dw      o_msg
           ghi     ra
           phi     rf
           glo     ra
           plo     rf
           ldi     0                   ; clear all modes
           plo     r9
sw_lp:     sep     scall               ; move past leading whitespace
           dw      f_ltrim
           ldn     rf                  ; check for switches
           smi     '-'                 ; which begin with -
           bnz     no_sw               ; jump if no switches
           inc     rf                  ; move to switch char
           lda     rf                  ; retrieve switch
           plo     re                  ; save it
           smi     'l'                 ; check for long mode
           lbnz    not_l               ; ignore others
           glo     r9                  ; get modes
           ori     1                   ; set long mode
           plo     r9                  ; and put it back
           lbr     sw_lp               ; loop back for more switches
not_l:     glo     re                  ; recover byte
           smi     'r'                 ; check for reverse sort
           lbnz    not_r               ; jump if not
           glo     r9                  ; get modes
           ori     010h                ; signal reverse sort
           plo     r9
           lbr     sw_lp               ; loop back for more switches
not_r:     glo     re                  ; recover character
           smi     's'                 ; check for sort on size
           lbnz    not_s               ; jump if not
           glo     r9                  ; get modes
           ori     028h                ; turn on sort by size
           plo     r9
           lbr     sw_lp               ; loop back for more
not_s:     glo     re                  ; recover byte
           smi     'd'                 ; check for sort on date
           lbnz    not_d
           glo     r9                  ; get modes
           ori     048h                ; turn on sort by date
           plo     r9                  ; store it back
           lbr     sw_lp               ; check for more switches
not_d:     glo     re                  ; recover character
           smi     'n'                 ; check sort by name
           lbnz    not_n               ; if not, then not a valid switch
           glo     r9                  ; get modes
           ori     088h                ; turn on sort by name
           plo     r9
           lbr     sw_lp               ; loop back for more switches
not_n:     glo     re                  ; recover character
           smi     'h'                 ; check show hidden files
           lbnz    sw_lp               ; if not, then not a valid switch
           glo     r9                  ; get modes
           ori     02h                 ; turn on show hidden files
           plo     r9
           lbr     sw_lp               ; loop back for more switches
no_sw:     mov     rb,mode             ; point to modes variable
           glo     r9                  ; get modes
           str     rb                  ; and save them
           sep     scall               ; open the directory
           dw      o_opendir
           ldi     0                   ; setup line counter
           plo     r7
dirloop:   ldi     0                   ; need to read 32 bytes
           phi     rc
           ldi     32
           plo     rc
           ldi     high buffer         ; setup transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; read files from dir
           dw      o_read
           glo     rc                  ; see if eof was hit
           smi     32
           lbnz    dirdone             ; jump if done
           ldi     high buffer         ; setup transfer buffer
           phi     rf
           ldi     low buffer
           plo     rf
           lda     rf                  ; check for good entry
           bnz     dirgood
           lda     rf                  ; check for good entry
           bnz     dirgood
           lda     rf                  ; check for good entry
           bnz     dirgood
           lda     rf                  ; check for good entry
           bnz     dirgood
           br      dirloop             ; not a valid entry, loop back
; *************************************************************
; *** Good entry found, copy needed data to dirents storage ***
; *************************************************************
dirgood:   mov     rf,buffer+6         ; point to flags byte
           ldn     rf                  ; retrieve it
           ani     8                   ; check hidden bit
           lbz     nothidden           ; jump if file is not hidden
           mov     rf,mode             ; point to modes
           ldn     rf                  ; retrieve modes
           ani     2                   ; see if show hidden is on
           lbnz    nothidden           ; show if -h was specified
           lbr     dirloop             ; otherwise do not show it

nothidden: mov     rf,next             ; need to retrieve next pointer
           lda     rf                  ; put into rc
           phi     rc
           ldn     rf
           plo     rc                  ; rc now points to blank space in dirents
           mov     rf,buffer+12        ; point to filename
           ldi     19                  ; 20 bytes per filename
           plo     re
namelp:    lda     rf                  ; get next byte from name
           lbz     namedn              ; jump if name is done
           str     rc                  ; store into dirents storage
           inc     rc
           dec     re                  ; decrement count
           glo     re                  ; check count
           lbnz    namelp              ; loop until all bytes copied
namedn:    mov     rf,buffer+6         ; point to flags byte
           ldn     rf                  ; get flags
           ani     1                   ; see if file is a directory
           lbz     namedn3             ; jump if not
           ldi     '/'                 ; store directory marker
           str     rc
           inc     rc
           dec     re
namedn3:   glo     re                  ; see if have full 20 bytes
           lbz     namedn2             ; jump if so
           ldi     ' '                 ; otherwise add a space
           str     rc
           inc     rc
           dec     re                  ; decrement count
           lbr     namedn3             ; loop until have 20 byte name
namedn2:   ldi     0                   ; write a string terminator
           str     rc
           inc     rc
           inc     rc
           mov     rf,buffer+6         ; copy the 5 bytes of the flags and date/time
           lda     rf
           str     rc
           inc     rc
           lda     rf
           str     rc
           inc     rc
           lda     rf
           str     rc
           inc     rc
           lda     rf
           str     rc
           inc     rc
           lda     rf
           str     rc
           inc     rc
; *************************************************
; *** Necessary DIRENT data has now been copied ***
; *** Next get file size                        ***
; *************************************************
           push    r7
           push    r8
           push    rc
           sep     scall               ; get file size
           dw      getsize
           pop     rc
           ghi     r8                  ; store into record
           str     rc
           inc     rc
           glo     r8
           str     rc
           inc     rc
           ghi     r7
           str     rc
           inc     rc
           glo     r7
           str     rc
           inc     rc
           pop     r8
           pop     r7
; ***********************
; *** Done with entry ***
; ***********************
           ldi     0                   ; write terminator into list
           str     rc
           mov     rf,next             ; save new pointer
           ghi     rc
           str     rf
           inc     rf
           glo     rc
           str     rf
           lbr     dirloop             ; keep reading entries

; **************************************************************************
; *** Done reading directory, now it needs to be processed and displayed ***
; **************************************************************************
dirdone:   sep     scall               ; close the directory
           dw      o_close

           mov     rf,mode             ; point to mode
           ldn     rf                  ; recover mode
           plo     rb                  ; save it here
           ani     08h                 ; is sorting turned on
           lbz     display             ; jump if not 
           glo     rb                  ; recover modes
           ani     080h                ; check for name sort
           lbnz    name                ; jump if so
           glo     rb                  ; recover modes
           ani     020h                ; check for size sort
           lbnz    sortsize
           glo     rb                  ; recover modes
           ani     040h                ; check for date sort
           lbnz    sortdate
           lbr     display

sortdate:  glo     rb                  ; get mode
           ani     010h                ; see if reverse
           lbnz    daterev             ; jump if reverse name sort
           sep     scall               ; sort by name ascending
           dw      sortda
           lbr     display
daterev:   sep     scall               ; sort by name descending
           dw      sortdd
           lbr     display

sortsize:  glo     rb                  ; get mode
           ani     010h                ; see if reverse
           lbnz    sizerev             ; jump if reverse name sort
           sep     scall               ; sort by name ascending
           dw      sortsa
           lbr     display
sizerev:   sep     scall               ; sort by name descending
           dw      sortsd
           lbr     display

name:      glo     rb                  ; get mode
           ani     010h                ; see if reverse
           lbnz    namerev             ; jump if reverse name sort
           sep     scall               ; sort by name ascending
           dw      sortna
           lbr     display
namerev:   sep     scall               ; sort by name descending
           dw      sortnd
           lbr     display



display:   mov     rf,dirents          ; point to dirents storage
           ldi     4                   ; setup counter
           plo     rc
displp:    ldn     rf                  ; see if done with list
           lbz     complete            ; jump if done
           push    rf                  ; save position
           sep     scall               ; display current filename
           dw      o_msg
           glo     rb                  ; get mode byte
           shr                         ; shift long/short into df
           lbdf    longdsp             ; jump if long display
           dec     rc                  ; decrement counter
           glo     rc                  ; see if zero
           lbnz    short               ; jump if not
           sep     scall               ; do a cr/lf
           dw      o_inmsg
           db      10,13,0
           ldi     4                   ; reset counter
           plo     rc
           lbr     short
longdsp:   pop     rf
           push    rf                  ; save position
           push    rf
           glo     rf                  ; point to flags/date/time
           adi     21
           plo     ra
           ghi     rf
           adci    0
           phi     ra

           lda     ra                  ; get flags
           ani     2                   ; is file executable
           lbz     longdsp2            ; jump if not
           sep     scall               ; show as executable
           dw      o_inmsg
           db      '* ',0
           lbr     longdsp3
longdsp2:  sep     scall               ; non executable
           dw      o_inmsg
           db      '  ',0
longdsp3:  mov     rf,buffer           ; point to buffer
           sep     scall               ; convert datetime
           dw      datetime
           mov     rf,buffer           ; point back to buffer
           sep     scall               ; and display it
           dw      o_msg
           pop     rf                  ; recover dirent pointer
           glo     rf                  ; move to size
           adi     26
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           lda     rf                  ; retrieve size into r7:r8
           phi     r7
           lda     rf
           plo     r7
           lda     rf
           phi     r8
           lda     rf
           plo     r8
           sep     scall               ; display the size
           dw      itoa
           sep     scall               ; display cr/lf
           dw      docrlf
short:     pop     rf                  ; recover dirents position
           glo     rf                  ; point to next entry
           adi     30
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           lbr     displp              ; loop until all displayed

complete:  sep     scall               ; final cr/lf
           dw      docrlf
return:    sep     sret                ; return to os



; ***********************************
; *** Sort list by name ascending ***
; ***********************************
sortna:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortna1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortna2:   ldn     rd                  ; get byte from next entry
           lbz     sortna3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           sep     scall               ; compare strings
           dw      f_strcmp
           phi     r7                  ; save result
           pop     rd                  ; recover indexes
           pop     rf
           ghi     r7                  ; get compare result
           smi     1                   ; was string1 > string2
           lbnz    sortna4             ; jump if not
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortna4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortna2             ; loop to check next entry
sortna3:   glo     r7                  ; get flag
           lbnz    sortna              ; jump if entries were changed
           sep     sret                ; otherwise return to caller

; ************************************
; *** Sort list by name descending ***
; ************************************
sortnd:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortnd1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortnd2:   ldn     rd                  ; get byte from next entry
           lbz     sortnd3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           sep     scall               ; compare strings
           dw      f_strcmp
           phi     r7                  ; save result
           pop     rd                  ; recover indexes
           pop     rf
           ghi     r7                  ; get compare result
           smi     0ffh                ; was string1 < string2
           lbnz    sortnd4             ; jump if not
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortnd4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortnd2             ; loop to check next entry
sortnd3:   glo     r7                  ; get flag
           lbnz    sortnd              ; jump if entries were changed
           sep     sret                ; otherwise return to caller
           

; ***********************************
; *** Sort list by size ascending ***
; ***********************************
sortsa:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortsa1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortsa2:   ldn     rd                  ; get byte from next entry
           lbz     sortsa3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           glo     rf                  ; point to size field
           adi     26
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           glo     rd                  ; point to size field
           adi     26
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           ldi     4                   ; need to compare 4 bytes
           plo     re
sortsal1:  lda     rd                  ; get second number
           str     r2                  ; store for subtract
           lda     rf                  ; byte from first number
           sd                          ; subtract
           lbnf    sortsans            ; jump if need swap
           lbnz    sortsano            ; not zero means done
           dec     re                  ; decrement count
           glo     re                  ; get count
           lbnz    sortsal1            ; jump if more to check
sortsano:  pop     rd                  ; recover positions
           pop     rf
           lbr     sortsa4             ; and then move on
sortsans:  pop     rd                  ; recover positions
           pop     rf
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortsa4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortsa2             ; loop to check next entry
sortsa3:   glo     r7                  ; get flag
           lbnz    sortsa              ; jump if entries were changed
           sep     sret                ; otherwise return to caller

; ************************************
; *** Sort list by size descending ***
; ************************************
sortsd:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortsd1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortsd2:   ldn     rd                  ; get byte from next entry
           lbz     sortsd3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           glo     rf                  ; point to size field
           adi     26
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           glo     rd                  ; point to size field
           adi     26
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           ldi     4                   ; need to compare 4 bytes
           plo     re
sortsdl1:  lda     rd                  ; get second number
           str     r2                  ; store for subtract
           lda     rf                  ; byte from first number
           sm                          ; subtract
           lbnf    sortsdns            ; jump if need swap
           lbnz    sortsdno            ; done if not equal
           dec     re                  ; decrement count
           glo     re                  ; get count
           lbnz    sortsdl1            ; jump if more to check
sortsdno:  pop     rd                  ; recover positions
           pop     rf
           lbr     sortsd4             ; and then move on
sortsdns:  pop     rd                  ; recover positions
           pop     rf
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortsd4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortsd2             ; loop to check next entry
sortsd3:   glo     r7                  ; get flag
           lbnz    sortsd              ; jump if entries were changed
           sep     sret                ; otherwise return to caller

; ***********************************
; *** Sort list by date ascending ***
; ***********************************
sortda:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortda1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortda2:   ldn     rd                  ; get byte from next entry
           lbz     sortda3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           glo     rf                  ; point to date field
           adi     22
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           glo     rd                  ; point to date field
           adi     22
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           ldi     2                   ; need to compare 2 bytes
           plo     re
sortdal1:  lda     rd                  ; get second number
           str     r2                  ; store for subtract
           lda     rf                  ; byte from first number
           sd                          ; subtract
           lbnf    sortdans            ; jump if need swap
           lbnz    sortdano            ; not zero means done
           dec     re                  ; decrement count
           glo     re                  ; get count
           lbnz    sortdal1            ; jump if more to check
sortdano:  pop     rd                  ; recover positions
           pop     rf
           lbr     sortda4             ; and then move on
sortdans:  pop     rd                  ; recover positions
           pop     rf
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortda4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortda2             ; loop to check next entry
sortda3:   glo     r7                  ; get flag
           lbnz    sortda              ; jump if entries were changed
           sep     sret                ; otherwise return to caller

; ************************************
; *** Sort list by size descending ***
; ************************************
sortdd:    mov     rf,dirents          ; point to dirents storage
           ldn     rf                  ; get byte
           lbz     return              ; no sort if no entries
           mov     rd,dirents+30       ; point to second entry
           ldn     rd                  ; get byte
           lbz     return              ; return if only 1 entry
sortdd1:   ldi     0                   ; zero flag
           plo     r7                  ; store it
sortdd2:   ldn     rd                  ; get byte from next entry
           lbz     sortdd3             ; jump if end of list
           push    rf                  ; save indexes
           push    rd
           glo     rf                  ; point to size field
           adi     22
           plo     rf
           ghi     rf
           adci    0
           phi     rf
           glo     rd                  ; point to size field
           adi     22
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           ldi     2                   ; need to compare 2 bytes
           plo     re
sortddl1:  lda     rd                  ; get second number
           str     r2                  ; store for subtract
           lda     rf                  ; byte from first number
           sm                          ; subtract
           lbnf    sortddns            ; jump if need swap
           lbnz    sortddno            ; done if not equal
           dec     re                  ; decrement count
           glo     re                  ; get count
           lbnz    sortddl1            ; jump if more to check
sortddno:  pop     rd                  ; recover positions
           pop     rf
           lbr     sortdd4             ; and then move on
sortddns:  pop     rd                  ; recover positions
           pop     rf
           ldi     1                   ; signal a swap happened
           plo     r7
           sep     scall               ; swap the two entries
           dw      swap
sortdd4:   mov     rf,rd               ; point first to second
           glo     rd                  ; add 30 to second
           adi     30
           plo     rd
           ghi     rd
           adci    0
           phi     rd
           lbr     sortdd2             ; loop to check next entry
sortdd3:   glo     r7                  ; get flag
           lbnz    sortdd              ; jump if entries were changed
           sep     sret                ; otherwise return to caller

; **********************************
; *** Swap two directory entries ***
; **********************************
swap:      push    rf                  ; save indexes
           push    rd
           ldi     30                  ; 30 bytes to swap
           plo     re
swaplp:    ldn     rf                  ; get byte from first
           str     r2                  ; save it
           ldn     rd                  ; get byte from second
           str     rf                  ; store into first
           ldn     r2                  ; recover first one
           str     rd                  ; byte is now swapped
           inc     rd
           inc     rf
           dec     re                  ; decrement count
           glo     re                  ; see if done
           lbnz    swaplp              ; loop until done
           pop     rd                  ; recover indexes
           pop     rf
           sep     sret                ; return to caller





; ***** old code to be removed *****
           ldi     low buffer          ; point to filename
           adi     12
           plo     rf
           plo     r8                  ; make a copy here
           ldi     high buffer
           adci    0
           phi     rf
           phi     r8
           ldi     0                   ; need to find size
           plo     r9
size_lp:   lda     r8                  ; load next byte
           bz      size_dn             ; jump if found end
           inc     r9                  ; increment count
           inc     r7                  ; and terminal position
           br      size_lp             ; keep going til end found
size_dn:   inc     r9                  ; accomodate a trailing space
           glo     r7                  ; get terminal position
           smi     79                  ; see if off end
           lbnf    size_ok             ; jump if not
           sep     scall               ; move to next line
           dw      docrlf
           glo     r9                  ; get size of next entry
           plo     r7                  ; new terminal size
size_ok:   sep     scall               ; display the name
           dw      o_msg
           ldi     low buffer          ; point to flags
           adi     6
           plo     rf
           ldi     high buffer
           adci    0
           phi     rf
           ldn     rf                  ; get flags
           ani     1                   ; see if entry is a directory
           bz      notdir              ; jump if not
           ldi     '/'                 ; indicate a dir
           sep     scall
           dw      o_type
           inc     r7                  ; accomodate the /
notdir:    ldi     ' '                 ; trailing space
           sep     scall
           dw      o_type
           inc     r7                  ; increment terminal position
           glo     r7                  ; see if at end
           smi     79
           lbnf    term_lp             ; jump if not
           sep     scall               ; perform a cr/lf
           dw      docrlf
           ldi     0                   ; set new terminal width
           plo     r7
           br      dirloop             ; loop back for next entry
term_lp:   glo     r7                  ; get terminal width
           ani     15                  ; uses 16 as tabstop
           bnz     notdir              ; jump if not at tabstop
           ldn     rb                  ; get mode
           bnz     long                ; jump if long mode
           br      dirloop             ; loop for next entry
long:      ldi     low buffer          ; point to directory entry
           adi     7                   ; date field
           plo     ra
           ldi     high buffer
           adci    0                   ; propagate carry
           phi     ra
           ldi     high buffer2        ; point to conversion buffer
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; convert the date/time
           dw      datetime
           ldi     high buffer2        ; point to conversion buffer
           phi     rf
           ldi     low buffer2
           plo     rf
           sep     scall               ; display it
           dw      o_msg


           inc     rb                  ; point to size flag
           ldn     rb                  ; retrieve it
           dec     rb                  ; put rb back
           lbz     do_crlf             ; loop back if no size requested


; ************************
; *** Get size of file ***
; *** Returns R8:R7    ***
; ************************
getsize:   mov     rf,buffer           ; point to directory entry buffer
           inc     rf                  ; point to starting lump
           inc     rf
           lda     rf                  ; get starting lump
           phi     ra
           ldn     rf
           plo     ra
           ldi     0                   ; setup count
           phi     rc
           plo     rc
sz_loop:   sep     scall               ; read value of lump
           dw      o_rdlump
           ghi     ra                  ; check for end of chain
           smi     0feh
           lbnz    not_end             ; jump if not
           glo     ra                  ; check low byte as well
           smi     0feh
           lbz     sz_done             ; jump if found end
not_end:   inc     rc                  ; increment lump count
           lbr     sz_loop             ; and keep looking
sz_done:   ldi     0                   ; setup final size
           plo     r7
           phi     r8
           glo     rc
           phi     r7
           ghi     rc
           plo     r8                  ; R8:R7 now has AUs*256 bytes
           ghi     r7                  ; AU * 512 bytes
           shl
           phi     r7
           glo     r8
           shlc
           plo     r8
           ghi     r8
           shlc
           phi     r8                  ; R8:R7 now has size minus EOF position
           ghi     r7                  ; AU * 1024 bytes
           shl
           phi     r7
           glo     r8
           shlc
           plo     r8
           ghi     r8
           shlc
           phi     r8                  ; R8:R7 now has size minus EOF position
           ghi     r7                  ; AU * 2048 bytes
           shl
           phi     r7
           glo     r8
           shlc
           plo     r8
           ghi     r8
           shlc
           phi     r8                  ; R8:R7 now has size minus EOF position
           ghi     r7                  ; AU * 4096 bytes
           shl
           phi     r7
           glo     r8
           shlc
           plo     r8
           ghi     r8
           shlc
           phi     r8                  ; R8:R7 now has size minus EOF position
           mov     rf,buffer+5         ; point to EOF lsb
           ldn     rf                  ; get EOF lsb
           str     r2                  ; store for add
           glo     r7
           add
           plo     r7
           dec     rf                  ; point to EOF msb
           ldn     rf                  ; add it in
           str     r2
           ghi     r7
           adc
           phi     r7
           glo     r8                  ; propagate carry
           adci    0
           plo     r8
           ghi     r8
           adci    0
           phi     r8
           sep     sret                ; return size to caller
       
do_crlf:   ldi     high crlf           ; point to crlf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           ldi     0                   ; set new terminal width
           plo     r7
           lbr     dirloop             ; to next entry
docrlf:    glo     rf                  ; save rf
           stxd
           ghi     rf
           stxd
           ldi     high crlf           ; ponit to cr/lf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           irx                         ; recover original rf
           ldxa
           phi     rf
           ldx
           plo     rf
           sep     sret                ; and return

; ****************************************************
; *** Output 2 digit decimal number with leading 0 ***
; *** D - value to output                          ***
; *** RF - buffer to write value to                ***
; ****************************************************
intout2:   str     r2                  ; save value for a moment
           ldi     0                   ; setup count
           plo     re
           ldn     r2                  ; retrieve it
intout2lp: smi     10                  ; subtract 10
           lbnf    intout2go           ; jump if too small
           inc     re                  ; increment tens
           lbr     intout2lp           ; and keep looking
intout2go: adi     10                  ; make positive again
           str     r2                  ; save units
           glo     re                  ; get tens
           adi     '0'                 ; convert to ascii
           str     rf                  ; store into buffer
           inc     rf
           ldn     r2                  ; recover units
           adi     '0'                 ; convert to ascii
           str     rf                  ; and store into buffer
           inc     rf
           sep     sret                ; return to caller

; ***********************************************
; *** Display date/time from descriptor entry ***
; *** RA - pointer to packed date/time        ***
; *** RF - where to put it                    ***
; ***********************************************
datetime:  glo     rd                  ; save consumed register
           stxd
           ghi     rd
           stxd
           lda     ra                  ; get year/month
           shr                         ; shift high month bit into DF
           ldn     ra                  ; get low bits of month
           shrc                        ; shift high bit in
           shr                         ; then shift into position
           shr
           shr
           shr
           sep     scall               ; convert month output
           dw      intout2
           ldi     '/'                 ; need a slash
           str     rf                  ; place into output
           inc     rf
           ldn     ra                  ; recover day
           ani     01fh                ; mask for day
           sep     scall               ; convert month output
           dw      intout2
           ldi     '/'                 ; need a slash
           str     rf                  ; place into output
           inc     rf
           dec     ra                  ; point back to year
           lda     ra                  ; get year
           shr                         ; shift out high bit of month
           adi     180                 ; add in 1970
           plo     rd                  ; put in RD for conversion
           ldi     0                   ; need zero
           adci    7                   ; propagate carry
           phi     rd
           sep     scall               ; conver it 
           dw      f_uintout
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           inc     ra                  ; point to time
           ldn     ra                  ; retrieve hours
           shr                         ; shift to proper position
           shr
           shr
           sep     scall               ; output it
           dw      intout2
           ldi     ':'                 ; need a colon
           str     rf                  ; place into output
           inc     rf
           lda     ra                  ; get minutes
           ani     07h                 ; strip out hours
           shl                         ; shift to needed spot
           shl
           shl
           str     r2                  ; save for combination
           ldn     ra                  ; get low bits of minutes
           shr                         ; shift into position
           shr
           shr
           shr
           shr
           or                          ; combine with high bites
           sep     scall               ; output it
           dw      intout2
           ldi     ':'                 ; need a colon
           str     rf                  ; place into output
           inc     rf
           ldn     ra                  ; get seconds
           ani     1fh                 ; strip minutes out
           shl                         ; multiply by 2
           sep     scall               ; output it
           dw      intout2
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           ldi     ' '                 ; need a space
           str     rf                  ; place into output
           inc     rf
           ldi     0                   ; need terminator
           str     rf
           irx                         ; recover consumed register
           ldxa
           phi     rd
           ldx
           plo     rd
           sep     sret                ; and return

; *****************************************
; ***** Convert R7:R8 to bcd in M[RF] *****
; *****************************************
tobcd:     push    rf           ; save address
           ldi     10           ; 10 bytes to clear
           plo     re
tobcdlp1:  ldi     0
           str     rf           ; store into answer
           inc     rf
           dec     re           ; decrement count
           glo     re           ; get count
           lbnz    tobcdlp1     ; loop until done
           pop     rf           ; recover address
           ldi     32           ; 32 bits to process
           plo     r9
tobcdlp2:  ldi     10           ; need to process 5 cells
           plo     re           ; put into count
           push    rf           ; save address
tobcdlp3:  ldn     rf           ; get byte
           smi     5            ; need to see if 5 or greater
           lbnf    tobcdlp3a    ; jump if not
           adi     8            ; add 3 to original number
           str     rf           ; and put it back
tobcdlp3a: inc     rf           ; point to next cell
           dec     re           ; decrement cell count
           glo     re           ; retrieve count
           lbnz    tobcdlp3     ; loop back if not done
           glo     r8           ; start by shifting number to convert
           shl
           plo     r8
           ghi     r8
           shlc
           phi     r8
           glo     r7
           shlc
           plo     r7
           ghi     r7
           shlc
           phi     r7
           shlc                 ; now shift result to bit 3
           shl
           shl
           shl
           str     rf
           pop     rf           ; recover address
           push    rf           ; save address again
           ldi     10           ; 10 cells to process
           plo     re
tobcdlp4:  lda     rf           ; get current cell
           str     r2           ; save it
           ldn     rf           ; get next cell
           shr                  ; shift bit 3 into df
           shr
           shr
           shr
           ldn     r2           ; recover value for current cell
           shlc                 ; shift with new bit
           ani     0fh          ; keep only bottom 4 bits
           dec     rf           ; point back
           str     rf           ; store value
           inc     rf           ; and move to next cell
           dec     re           ; decrement count
           glo     re           ; see if done
           lbnz    tobcdlp4     ; jump if not
           pop     rf           ; recover address
           dec     r9           ; decrement bit count
           glo     r9           ; see if done
           lbnz    tobcdlp2     ; loop until done
           sep     sret         ; return to caller

; ***************************************************
; ***** Print number in R7:R8 as signed integer *****
; ***************************************************
itoa:      push    rf           ; save consumed registers
           push    r8
           glo     r2           ; make room on stack for buffer
           smi     11
           plo     r2
           ghi     r2
           smbi    0
           phi     r2
           mov     rf,r2        ; RF is output buffer
           inc     rf
           ghi     r7           ; get high byte
           shl                  ; shift bit to DF
           lbdf    itoan        ; negative number
itoa1:     sep     scall        ; convert to bcd
           dw      tobcd
           mov     rf,r2
           inc     rf
           ldi     10
           plo     r8
           ldi     9            ; max 9 leading zeros
           phi     r8
loop1:     lda     rf
           lbz     itoaz        ; check leading zeros
           str     r2           ; save for a moment
           ldi     0            ; signal no more leading zeros
           phi     r8
           ldn     r2           ; recover character
itoa2:     adi     030h
           sep     scall
           dw      o_type
itoa3:     dec     r8
           glo     r8
           lbnz    loop1
           glo     r2           ; pop work buffer off stack
           adi     11
           plo     r2
           ghi     r2
           adci    0
           phi     r2
           pop     r8           ; recover consumed registers
           pop     rf
           sep     sret         ; return to caller
itoaz:     ghi     r8           ; see if leading have been used up
           lbz     itoa2        ; jump if so
           smi     1            ; decrement count
           phi     r8
           lbr     itoa3        ; and loop for next character
itoan:     ldi     '-'          ; show negative
           sep     scall
           dw      o_type
           glo     r8           ; 2s compliment
           xri     0ffh
           adi     1
           plo     r8
           ghi     r8
           xri     0ffh
           adci    0
           phi     r8
           glo     r7
           xri     0ffh
           adci    0
           plo     r7
           ghi     r7
           xri     0ffh
           adci    0
           phi     r7
           lbr     itoa1        ; now convert/show number


crlf:      db      10,13,0
mode:      db      0
size:      db      0
next:      dw      0                   ; where to store dirents pointer

endrom:    equ     $

buffer:    ds      32
buffer2:   ds      64
dirents:   db      0


