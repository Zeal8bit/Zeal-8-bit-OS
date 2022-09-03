if test -f "disk.img"; then
    echo "disk.img already exists, removing it"
    rm disk.img
fi
echo "Creating romdisk..."
# TODO: Have Makefile to have a cleaner (sub)project
# Clean the project
rm -f *.o *.bin *.err
# Compile all the files into a binary init_TEXT.bin
# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
z88dk-z80asm -b -m init.asm parse.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm errors.asm && \
rm -f init.bin && mv init_TEXT.bin init.bin && \
# Pack some files inside a romdisk image
pack disk.img init.asm init.bin simple.txt
