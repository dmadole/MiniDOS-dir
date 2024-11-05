
all: dir.bin

lbr: dir.lbr

clean:
	rm -f dir.lst
	rm -f dir.bin
	rm -f dir.lbr

dir.bin: dir.asm include/bios.inc include/kernel.inc
	asm02 -L -b dir.asm
	rm -f dir.build

dir.lbr: dir.bin
	rm -f dir.lbr
	lbradd dir.lbr dir.bin

