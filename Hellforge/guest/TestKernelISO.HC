//WS2: the in-guest CD makers carry the AntichristOS identity
//(forge.py run guest/TestKernelISO.HC).  Builds a tiny bootable image
//on the B: RAM drive with RedSeaISO() and checks the El Torito ID, its
//checksum, the publisher id and the stage-1 messages assembled from
//Adam/Opt/Boot/BootDVD.HC.  Exit code: failed check count.
//(DskISO9660.HC is not tested: in stock V5.03 it no longer compiles,
//it uses the long-gone class CISO1DirEntry.)

I64 tki_bad=0;

U0 TkiFail(U8 *what)
{
  HfPrint("TKI FAIL %s\n",what);
  tki_bad++;
}

Bool TkiHas(U8 *base,I64 size,U8 *needle)
{
  I64 i,len=StrLen(needle);
  for (i=0;i+len<=size;i++)
    if (!MemCmp(base+i,needle,len))
      return TRUE;
  return FALSE;
}

U0 TkiCheck(U8 *name,Bool redsea)
{
  I64 size=0,i,sum=0;
  U8 *buf=FileRead(name,&size),*et,*s1;
  U16 *w;
  if (!buf || size<22*DVD_BLK_SIZE) {
    TkiFail("ISO missing or too small");
    return;
  }
  HfPrint("TKI %s %d bytes\n",name,size);
  et=buf+20*DVD_BLK_SIZE;
  w=et;
  for (i=0;i<16;i++)
    sum+=w[i];
  HfPrint("TKI  El Torito ID \"%s\" checksum %04X\n",et+4,sum&0xFFFF);
  if (StrCmp(et+4,"AntichristOS"))
    TkiFail("El Torito ID");
  if (sum&0xFFFF)
    TkiFail("El Torito checksum");
  if (redsea) {
    if (TkiHas(buf+16*DVD_BLK_SIZE,DVD_BLK_SIZE,"TempleOS RedSea"))
      HfPrint("TKI  publisher id kept (the kernel mounts by it)\n");
    else
      TkiFail("publisher id");
  }
  s1=buf+21*DVD_BLK_SIZE;
  if (TkiHas(s1,DVD_BOOT_LOADER_SIZE,"Summoning AntichristOS") &&
	TkiHas(s1,DVD_BOOT_LOADER_SIZE,"(and your soul)"))
    HfPrint("TKI  stage 1 says Summoning AntichristOS\n");
  else
    TkiFail("stage 1 message");
  Free(buf);
}

U0 TestKernelISO()
{
  Cd("B:/");
  DirMk("B:/Mini");
  CopyTree("T:/0000Boot","B:/Mini/0000Boot");
  RedSeaISO("B:/Mini.ISO.C","B:/Mini","B:/Mini/0000Boot/0000Kernel.BIN.C");
  TkiCheck("B:/Mini.ISO.C",TRUE);
  HfPrint("TKI END bad=%d\n",tki_bad);
  hf_exit_code=tki_bad;
}

TestKernelISO;
