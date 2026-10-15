                         AntichristOS V6.66
                    (SOtsirhcitnA, played forwards)

AntichristOS is a parody fork of TempleOS V5.03, the public domain 64-bit
operating system written by Terry A. Davis.  It is TempleOS played
backwards: hellfire palettes, an upside-down screen, backmasked music, a
tour through Dante's circles, and a language called Unholy C in which
every keyword can be spelled backwards.  Everything underneath -- the
kernel, the compiler, the libraries, the games -- is Terry A. Davis's work,
and it stays in the public domain.  It is a joke about heavy metal album
covers, not about anybody's faith.

You can't do much until you burn an AntichristOS CD/DVD from the ISO file
and boot it, or you aim your virtual machine's CD/DVD at the ISO file and
boot.  Abandon all hope, ye who boot here.  The files are compressed and
the source code can only be compiled by the AntichristOS compiler... which
is available when you boot the CD/DVD.  AntichristOS is 100% open source
with all source present.  Every sin is confessed in the source.

AntichristOS is 64-bit and will not run on 32-bit hardware.

AntichristOS requires 512 Meg of RAM minimum.  Your soul is optional.

AntichristOS may require you to enter I/O port addresses for the CD/DVD
drive and the hard drive.  In Windows, you can find I/O port info in the
Accessories/System Tools/System Info/Hardware Resources/I/O ports.  Look for
and write down "IDE", "ATA" or "SATA" port numbers.  In Linux, use
"lspci -v".  Then, boot the AntichristOS CD and try all combinations.
(Sorry, it's too difficult to figure-out port numbers, automatically.)

The source cannot be compiled outside AntichristOS because it's Unholy C
(HolyC, a nonstandard C/C++ dialect, with the keywords also accepted
backwards) and asm.  The original TempleOS lives at http://www.templeos.org.

The Hellforge/ directory is the host-side toolchain that builds the ISO and
boots it in QEMU.  It is not part of the CD.
