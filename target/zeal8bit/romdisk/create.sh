if test -f "disk.img"; then
    echo "disk.img already exists."
    exit 0
fi
echo "Creating romdisk..."
z88dk-z80asm -b -oinit.bin init.asm
# Pack some files inside a romdisk image
pack disk.img init.asm init.bin init.o
