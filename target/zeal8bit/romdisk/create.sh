if test -f "disk.img"; then
    echo "disk.img already exists, removing it"
    rm disk.img
fi
echo "Creating romdisk..."
# TODO: Have Makefile to have a cleaner (sub)project
z88dk-z80asm -b -m -oinit.bin init.asm parse.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm errors.asm && \
mv init*.bin init.bin && \
# Pack some files inside a romdisk image
pack disk.img init.asm init.bin simple.txt
