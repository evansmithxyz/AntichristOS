//Hellforge guest helpers (HolyC).  Injected into test ISOs only;
//never part of the repo tree that boots normally.
//Compiled at boot by the stock Compiler.BIN, so keep to plain HolyC.
//
//Polled 16550 UART on COM1 (0x3F8): no IRQs, no FIFOs, no Sleep() per
//char (unlike ::/Doc/Comm.HC which is IRQ driven and sleeps 10ms/char).
//
//Serial line protocol (host side: Hellforge/forge.py):
//  HELLFORGE_READY <tS>            boot finished, test about to start
//  HELLFORGE_EXCEPT <ch> <callers> uncaught exception in the test
//  HELLFORGE_EXIT <code>           guest is about to leave QEMU
//  HFDUMP BEGIN <name> <size>      framed file dump; then lines of
//  HFD <hex>                       up to 32 bytes each (uppercase hex),
//  HFDUMP END <crc32>              CRC-32 (zlib/IEEE) as 8 hex digits.
//  HELLFORGE_SHOT <name>           host takes a screenshot now (HfShot)
//Anything else is free text from the test.

#define HF_COM1		0x3F8
#define HF_UART_THR	0
#define HF_UART_IER	1
#define HF_UART_FCR	2
#define HF_UART_LCR	3
#define HF_UART_MCR	4
#define HF_UART_LSR	5
#define HF_EXIT_PORT	0xF4
#define HF_EXIT_EXCEPT	126

I64 hf_ser_base=HF_COM1;
Bool hf_ser_ready=FALSE;
I64 hf_exit_code=0;

U0 HfSerInit(I64 base=HF_COM1)
{//8N1, 115200 baud, polled.
  hf_ser_base=base;
  OutU8(base+HF_UART_IER,0);	//No IRQs
  OutU8(base+HF_UART_LCR,0x80);	//DLAB
  OutU8(base+HF_UART_THR,1);	//Divisor lo (115200)
  OutU8(base+HF_UART_IER,0);	//Divisor hi
  OutU8(base+HF_UART_LCR,3);	//8-none-1
  OutU8(base+HF_UART_FCR,0);	//No FIFO
  OutU8(base+HF_UART_MCR,3);	//DTR RTS, OUT2 off (no IRQ)
  hf_ser_ready=TRUE;
}

U0 HfPutChar(U8 ch)
{
  I64 i=0;
  if (!hf_ser_ready)
    HfSerInit;
  while (!(InU8(hf_ser_base+HF_UART_LSR)&0x20) && i<1000000)
    i++;
  OutU8(hf_ser_base+HF_UART_THR,ch);
}

U0 HfPutS(U8 *st)
{
  I64 ch;
  if (st)
    while (ch=*st++)
      HfPutChar(ch);
}

U0 HfPrint(U8 *fmt,...)
{//Like Print(), but to COM1.
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  HfPutS(buf);
  Free(buf);
}

U0 HfLine(U8 *st)
{
  HfPutS(st);
  HfPutChar('\n');
}

I64 HfCrc32(U8 *buf,I64 size)
{//CRC-32, same as zlib.crc32().
  I64 crc=0xFFFFFFFF,i,j;
  for (i=0;i<size;i++) {
    crc^=buf[i];
    for (j=0;j<8;j++) {
      if (crc&1)
	crc=(crc>>1)^0xEDB88320;
      else
	crc=crc>>1;
    }
  }
  return crc^0xFFFFFFFF;
}

U0 HfDumpBuf(U8 *name,U8 *buf,I64 size)
{//Framed hex dump of a buffer to COM1.
  U8 *hx="0123456789ABCDEF",line[80];
  I64 i=0,j,n;
  HfPrint("HFDUMP BEGIN %s %d\n",name,size);
  while (i<size) {
    n=size-i;
    if (n>32) n=32;
    line[0]='H';
    line[1]='F';
    line[2]='D';
    line[3]=' ';
    for (j=0;j<n;j++) {
      line[4+j*2]=hx[buf[i+j]>>4];
      line[5+j*2]=hx[buf[i+j]&15];
    }
    line[4+n*2]='\n';
    line[5+n*2]=0;
    HfPutS(line);
    i+=n;
  }
  HfPrint("HFDUMP END %08X\n",HfCrc32(buf,size));
}

Bool HfDumpFile(U8 *filename,U8 *name=NULL)
{//Hex-dump a file's raw bytes (FileRead: .Z files come out expanded).
  I64 size=0;
  U8 *buf=FileRead(filename,&size);
  if (!buf) {
    HfPrint("HFDUMP MISSING %s\n",filename);
    return FALSE;
  }
  if (!name) name=filename;
  HfDumpBuf(name,buf,size);
  Free(buf);
  return TRUE;
}

U0 HfExit(I64 code=0)
{//Leave QEMU via isa-debug-exit: host status=(code<<1)|1.
  HfPrint("HELLFORGE_EXIT %d\n",code);
  OutU8(HF_EXIT_PORT,code);
  //Not under QEMU (or no isa-debug-exit device): just park.
  while (TRUE)
    Yield;
}

U0 HfShot(U8 *name,I64 ms=1500)
{//Ask the host for a screenshot (<workdir>/<prefix>_<name>.png), then wait
//so it is taken before anything else changes.  name: [A-Za-z0-9_-] only.
  HfPrint("HELLFORGE_SHOT %s\n",name);
  Sleep(ms);
}

U0 HfPutExcept()
{//Call inside a catch block.
  HfPrint("HELLFORGE_EXCEPT %c %P %P %P %P\n",Fs->except_ch,
	Fs->except_callers[0],Fs->except_callers[1],
	Fs->except_callers[2],Fs->except_callers[3]);
}
