
;  Copyright 2023, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


          ; Definition files

          #include include/bios.inc
          #include include/kernel.inc


          ; Executable header block

            org   1ffah
            dw    begin
            dw    end-begin
            dw    begin

begin:      br    skipini

            db    11+80h
            db    5
            dw    2024
            dw    2

            db    'See github/dmadole/MiniDOS-dir for more information',0


skipini:    lda   ra                    ; skip any leading spaces
            lbz   nullarg
            sdi   ' '
            lbdf  skipini

            sdi   ' '-'-'               ; a dash starts an option
            lbnz  notdash

            lda   ra                    ; the v option is for verbose
            smi   'l'
            lbnz  dousage

            ldi   options.1
            phi   rb
            ldi   options.0
            plo   rb

            ldn   rb                    ; set the flag for verbose
            ori   1
            str   rb

            lda   ra                    ; make sure a space follows
            lbz   nullarg
            sdi   ' '
            lbdf  skipini

            lbr   dousage               ; if not then error


          ; If not an option, then it is the source path name.

notdash:    dec   ra                    ; back up to first char

            ghi   ra                    ; switch to rf
            phi   rf
            glo   ra
            plo   rf

            ldi   srcname.1             ; pointer to file name
            phi   ra
            ldi   srcname.0
            plo   ra
 
copysrc:    lda   rf                    ; done if end of name
            lbz   endargs

            str   ra                    ; else copy until end
            inc   ra
            sdi   ' '
            lbnf  copysrc

            dec   ra                    ; back to first space

skipend:    lda   rf
            lbz   endargs
            sdi   ' '
            lbdf  skipend

dousage:    sep   scall
            dw    o_inmsg
            db    'USAGE: dir [-l] [path]',13,10,0

return:     sep   sret


          ; If a path name argument was not provided, then get the current
          ; directory from Elf/OS.

nullarg:    ldi   srcname.1             ; pointer to path storage
            phi   ra
            phi   rf
            ldi   srcname.0
            plo   ra
            plo   rf

            ldi   0                     ; make null string
            str   rf

            sep   scall                 ; get current directory
            dw    o_chdir

skipcwd:    lda   ra                    ; skip to end
            lbnz  skipcwd

            dec   ra                    ; back to terminator


          ; If the source path does not end in a slash then add one so that
          ; opendir tries to open the path as a directory. Leave RA pointing
          ; to the slash, not the terminator so we know that we added it.

endargs:    str   ra                    ; terminate path name

            dec   ra                    ; if already a slash do nothing
            lda   ra
            smi   '/'
            lbz   slashed

            ldi   '/'                   ; else add a slash
            str   ra
            inc   ra

            ldi   0                     ; terminate path name
            str   ra

slashed:    ldi   source.1
            phi   rd
            ldi   source.0
            plo   rd

            ldi   srcname.1
            phi   rf
            ldi   srcname.0
            plo   rf

            ldi   16
            plo   r7

            sep   scall
            dw    opendir
            lbnf  destdir


            ldn   ra
            lbnz  unslash

            sep   scall
            dw    o_inmsg
            db    'ERROR: path is not directory',13,10,0

            sep   sret

unslash:    ldi   0
            str   ra

            sep   sret





destdir:    ldi   end.1                 ; pointer to memory for entries
            phi   r7
            ldi   end.0
            plo   r7

            ldi   k_heap.1              ; get start of heap pointer
            phi   rf
            ldi   k_heap.0
            plo   rf

            lda   rf                    ; will build index downward
            phi   r8
            ldn   rf
            plo   r8

            ldi   0                     ; zero count
            phi   r9
            plo   r9

            ldi   source.1
            phi   rd
            ldi   source.0
            plo   rd

            ldi   0                     ; size of directory entry
            phi   rc
            ldi   32
            plo   rc

nextent:    ghi   r7                    ; next free memory
            phi   rf
            glo   r7
            plo   rf

            sep   scall                 ; read the entry
            dw    o_read
            lbdf  inpfail

            glo   rc                    ; if less than 30 bytes then done
            smi   32
            lbnf  lastdir

            ghi   r7                    ; pointer into entry
            phi   rf
            glo   r7
            plo   rf

            inc   rf
            inc   rf

            lda   rf                    ; if au is zero then skip
            lbnz  entused
            ldn   rf
            lbz   nextent

entused:    glo   r7                    ; move memory pointer to name
            adi   12
            plo   r7
            ghi   r7
            adci  0
            phi   r7

            ghi   r7                    ; add pointer to list
            dec   r8
            str   r8
            glo   r7
            dec   r8
            str   r8

skipnam:    lda   r7                    ; skip over name
            lbnz  skipnam

            inc   r9                    ; increment count of entries

            lbr   nextent               ; process next entry



          ; If the list is empty then there is nothing to do, just exit.

lastdir:    glo   r9
            lbnz  notzero
            ghi   r9
            lbz   return


          ; Else setup for the sort by taking a copy of the count of items
          ; into R7 which will be the count of the unsorted prefix of the
          ; list. Change X to RD for use in the comparison inner loop.

notzero:    sep   scall                 ; output a separator line
            dw    o_inmsg
            db    13,10,0

            glo   r9                    ; partion divider size
            plo   r7
            ghi   r9
            phi   r7

            sex   rd                    ; for sm in name comparison


          ; Perform one pass of the selection sort. Drop the partition point
          ; down by one on each pass, if there is no unsorted part left then
          ; we are done (also if we only had one item to start with).

onepass:    dec   r7                    ; compare one fewer than length

            glo   r7                    ; if no comparisons then done
            bnz   gotmore
            ghi   r7
            bz    display


          ; Take a copy of the partition point to use to count entries as
          ; we scan through and compare them.

gotmore:    ghi   r7                    ; copy count of unsorted entries
            phi   rc
            glo   r7
            plo   rc

            ghi   r8                    ; start largest at first item
            phi   rb
            glo   r8
            plo   rb

            inc   rb                    ; advance to second byte


          ; This sets the highest value pointer to the current pointer, which
          ; is done both at the start of the pass, and also any time a new
          ; highest value is found (except if it's the very last comparison).

largest:    ghi   rb                    ; update largest to current
            phi   ra
            glo   rb
            plo   ra


          ; The loop returns back to here when a new highest value is not
          ; found, in which case we simply advance to the next candidate.

sortent:    dec   ra                    ; keep largest, advance current
            inc   rb

            lda   ra                    ; get pointer to largest name
            plo   rd
            ldn   ra
            phi   rd

            lda   rb                    ; get pointer to current name
            plo   rf
            ldn   rb
            phi   rf

            dec   rc                    ; decrement count


          ; Compare the names of the highest yet found and the current item.
          ; Assume there are no duplicates since these are directory entries.

cmpname:    lda   rf                    ; if end of rf then no swap
            bz    skipent

            sm                          ; if rf is less then no swap
            bnf   skipent

            inc   rd                    ; if same then keep comparing
            bz    cmpname


          ; The current item is higher than the last highest item. If this
          ; is already the last item in the list then end this pass, else
          ; remember this as the new highest item this pass and continue.

            glo   rc                    ; if not last then update current
            bnz   largest
            ghi   rc
            bnz   largest

            br    onepass               ; otherwise just start a new pass


          ; If the current item is not larger than the highest seen yet,
          ; check the next item unless we are at the end of the list.

skipent:    glo   rc                    ; if not last keep checking
            bnz   sortent
            ghi   rc
            bnz   sortent


          ; If we completed a pass then swap the highest found with the
          ; last item, which will decrease the unsorted part by one entry.

            ldn   ra                    ; swap the second entry bytes
            str   r2
            ldn   rb
            str   ra
            ldn   r2
            str   rb

            dec   ra                    ; point to first byte
            dec   rb

            ldn   ra                    ; swap the first entry bytes
            str   r2
            ldn   rb
            str   ra
            ldn   r2
            str   rb

            br    onepass               ; and start a new loop











display:    ldi   options.1
            phi   rb
            ldi   options.0
            plo   rb

            ldn   rb                   ; for long form display
            ani   1
            lbnz  longopt

            ldi   3                    ; column counter default
            phi   rc

            ghi   r9                   ; default if more than 256
            bnz   above4

            glo   r9                   ; default if more than 3
            smi   4
            lbdf  above4

            adi   3                    ; else entries in last row
            phi   rc



above4:     ldi   buffer.1             ; pointer to output buffer
            phi   rf
            ldi   buffer.0
            plo   rf



notlast:    lda   r8                   ; pointers to name and flags
            plo   rb
            smi   6
            plo   rd
            lda   r8
            phi   rb
            smbi  0
            phi   rd

            ldi   20                   ; column width in characters
            plo   rc

colsize:    lda   rb                   ; subtract length of name
            str   rf
            inc   rf
            dec   rc
            bnz   colsize

            dec   rf                   ; adjust for zeroterminator
            inc   rc



            ldn   rd                   ; if not directory flag set
            shr
            lbnf  nodirec

            ldi   '/'                  ; else output slash to buffer
            str   rf

            inc   rf                   ; adjust pointer and count
            dec   rc                  





nodirec:    dec   r9                   ; decrement entry count

            ghi   rc                   ; end of line if last column
            lbz   newline


padname:    glo   rc                   ; if end of column width
            lbz   notline

            ldi   ' '                  ; pad with spaces to column width
            str   rf
            inc   rf
            dec   rc
            lbr   padname


notline:    dec   rc                   ; decrement column in msb

            lbr   notlast              ; output next column


newline:    ldi   13                   ; add carriage return to buffer
            str   rf
            inc   rf

            ldi   10                   ; add line feed to buffer
            str   rf
            inc   rf

            ldi   0                    ; add terminator
            str   rf

            ldi   buffer.1             ; pointer back to beginning
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                ; output buffer
            dw    o_msg



            glo   r9                   ; continue if not end of names
            lbnz  display
            ghi   r9
            lbnz  display

            sep   sret                 ; when done then exit



longopt:    lda   r8
            plo   ra
            smi   6
            plo   rb
            lda   r8
            phi   ra
            smbi  0
            phi   rb

            ldi   buffer.1
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   20
            plo   rc

copynam:    lda   ra
            str   rf
            inc   rf
            dec   rc
            lbnz  copynam

            dec   rf
            inc   rc

            ldn   rb                   ; if not directory flag set
            ani   1
            lbz   notadir

            ldi   '/'                  ; else output slash to buffer
            str   rf

            inc   rf                   ; adjust pointer and count
            dec   rc                  

notadir:    glo   rc
            lbz   endpads

            ldi   ' '
            str   rf
            inc   rf

            dec   rc
            lbr   notadir

endpads:    ldn   rb
            ani   2
            lbz   notexec

            ldi   '*'
            str   rf
            inc   rf

            lbr   isaexec

notexec:    ldi   ' '
            str   rf
            inc   rf

isaexec:    ldi   ' '
            str   rf
            inc   rf


            inc   rb

            lda   rb
            shr
            plo   rd

            ldn   rb
            shrc
            shr
            shr
            shr
            shr

            sep   scall
            dw    dateint

            ldi   '/'
            str   rf
            inc   rf

            lda   rb
            ani   31

            sep   scall
            dw    dateint

            ldi   '/'
            str   rf
            inc   rf

            glo   rd
            smi   100-72
            lbdf  year20c

            ldi   '1'
            str   rf
            inc   rf

            ldi   '9'
            str   rf
            inc   rf

            glo   rd
            adi   72

            lbr   year19c

year20c:    ldi   '2'
            str   rf
            inc   rf

            ldi   '0'
            str   rf
            inc   rf

            glo   rd
            smi   100-72
            
year19c:    sep   scall
            dw    dateint

            ldi   ' '
            str   rf
            inc   rf

            ldn   rb
            shr
            shr
            shr

            sep   scall
            dw    dateint

            ldi   ':'
            str   rf
            inc   rf

            lda   rb
            shl
            shl
            shl
            str   r2

            ldn   rb
            shr
            shr
            shr
            shr
            shr
            add
            ani   63

            sep   scall
            dw    dateint
            
            ldi   ':'
            str   rf
            inc   rf

            ldn   rb
            shl
            ani   63

            sep   scall
            dw    dateint

            ldi   ' '
            str   rf
            inc   rf

            str   rf
            inc   rf




            glo   rb
            smi   8
            plo   rb
            ghi   rb
            smbi   0
            phi   rb

            ghi   r8
            stxd

            ldi   (source+9).1
            phi   ra
            ldi   (source+9).0
            plo   ra

            ldn   ra
            phi   r8

            lda   rb
            phi   ra
            lda   rb
            plo   ra

            lda   rb
            phi   rd
            lda   rb
            plo   rd

            ldi   -1
            phi   rc
            plo   rc

getsize:    inc   rc

            sep   scall
            dw    o_rdlump

            ghi   ra
            smi   0feh
            lbnz  getsize

            glo   ra
            smi   0feh
            lbnz  getsize

            ghi   rd
            str   r2

            ldi   4
            plo   re

shifter:    ghi   rc
            shr
            phi   rc
            glo   rc
            shrc
            plo   rc
            ghi   rd
            shrc
            phi   rd

            dec   re
            glo   re
            lbnz  shifter

            ghi   rd
            or
            phi   rd

            sep   scall
            dw    i2along


endlong:    irx
            ldx
            phi   r8

            ldi   13
            str   rf
            inc   rf

            ldi   10
            str   rf
            inc   rf

            ldi   0
            str   rf

            ldi   buffer.1
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    o_msg

            dec   r9

            glo   r9
            lbnz  longopt
            ghi   r9
            lbnz  longopt

            sep   sret




i2along:    ldi   divisor.1
            phi   ra
            ldi   divisor.0
            plo   ra

            sex   ra

            ldi   -1
            plo   rb

i2adivi:    inc   rb

i2aloop:    glo   rd
            sm
            plo   rd
            dec   ra
            ghi   rd
            smb
            phi   rd
            dec   ra
            glo   rc
            smb
            plo   rc

            inc   ra
            inc   ra

            lbdf  i2adivi

            glo   rd
            add 
            plo   rd
            dec   ra
            ghi   rd
            adc
            phi   rd
            dec   ra
            glo   rc
            adc
            plo   rc

            glo   rb
            lbz   i2askip

            ori   '0'
            str   rf
            inc   rf

            ldi   '0'
            plo   rb

i2askip:    dec   ra
            ldn   ra
            lbnz  i2aloop

            glo   rd
            adi   '0'

            str   rf
            inc   rf

            sep   sret

            db    0
            db    0,0,10
            db    0,0,100
            db    0,3,232
            db    0,39,16
            db    1,134,160
            db    15,66,64
            db    152,150,128

divisor:    equ   $-1



          ; A fast, simple integer to ASCII conversion for outputting the
          ; dates. This always outputs two digits, with leading zeroes.
          ; The input value is in D and the output is written at RF.

dateint:    str   r2                    ; save input value

            ldi   '0'-1                 ; for tens digit
            plo   re

            ldn   r2                    ; recover input value

intloop:    smi   10                    ; count tens
            inc   re
            lbdf  intloop

            str   r2                    ; save underflowed result

            glo   re                    ; put tens digit to output
            str   rf
            inc   rf

            ldn   r2                    ; recover underflow

            adi   '0'+10                ; convert to digit and output
            str   rf
            inc   rf

            sep   sret                  ; return



inpfail:    sep   scall
            dw    o_inmsg
            db    'failed',13,10,0

            sep   sret



          ; ------------------------------------------------------------------
          ; The o_open call can't open the root directory, but o_opendir can,
          ; however on Elf/OS 4 it returns a system filedescriptor that will
          ; be overwritten when opening the next file. So we call o_opendir
          ; but then create a copy of the file descriptor in that case.

opendir:    glo   rd                    ; save the passed descriptor
            stxd
            ghi   rd
            stxd

            glo   ra                    ; in elf/os 4 opendir trashes ra
            stxd
            ghi   ra
            stxd

            glo   r9                    ; and also r9
            stxd
            ghi   r9
            stxd

            sep   scall                 ; open the directory
            dw    o_opendir

            irx                         ; restore original r9
            ldxa
            phi   r9
            ldxa
            plo   r9

            ldxa                        ; and ra
            phi   ra
            ldxa
            plo   ra


          ; If opendir failed then no need to copy the descriptor, just 
          ; restore the original RD and return.

            lbnf  success               ; did opendir succeed?

            ldxa                        ; if not restore original rd
            phi   rd
            ldx
            plo   rd

            sep   sret                  ; and return


          ; If RD did not change, then opendir might have failed, or it may
          ; have succeeded on a later version of Elf/OS that uses the passed
          ; descriptor rather than a system descriptor. Either way, return.

success:    ghi   rd                    ; see if rd changed
            xor
            lbnz  changed

            irx                         ; if not, don't copy fildes
            sep   sret


          ; Otherwise, we opened the directory, but have been returned a 
          ; pointer to a system file descriptor. Copy it before returning.

changed:    ldxa                        ; get saved rd into r9
            phi   rf
            ldx
            plo   rf

            ldi   4                     ; first 4 bytes are offset
            plo   re

copyfd1:    lda   rd                    ; copy them 
            str   rf
            inc   rf

            dec   re                    ; until all 4 complete
            glo   re
            lbnz  copyfd1

            lda   rd                    ; next 2 are the dta pointer
            phi   r7
            lda   rd
            plo   r7

            lda   rf                    ; get for source and destination
            phi   r8
            lda   rf
            plo   r8

            ldi   13                    ; remaining byte count in fildes
            plo   re

copyfd2:    lda   rd                    ; copy remaining bytes
            str   rf
            inc   rf

            dec   re                    ; complete to total of 19 bytes
            glo   re
            lbnz  copyfd2

            ldi   255                   ; count to copy, mind the msb
            plo   re
            inc   re

copydta:    lda   r7                    ; copy two bytes at a time
            str   r8
            inc   r8
            lda   r7
            str   r8
            inc   r8

            dec   re                    ; continue until dta copied
            glo   re
            lbnz  copydta

            glo   rf                    ; set copy fildes back into rd
            smi   19
            plo   rd
            ghi   rf
            smbi  0
            phi   rd

            adi   0                     ; return with df cleared
            sep   sret

options:    db    0

          ; File descriptor used for both intput and output files.

source:     db    0,0,0,0
            dw    dta
            db    0,0,0,0,0,0,0,0,0,0,0,0,0

dirent:     ds    32

srcname:    ds    256

buffer:     ds    256


          ; Data transfer area that is included in executable header size
          ; but not actually included in executable.

dta:        ds    512

end:        end    begin
