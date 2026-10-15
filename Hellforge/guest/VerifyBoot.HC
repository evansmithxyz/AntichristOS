//Hellforge: check that the running image is the freshly bootstrapped one
//(forge.py selftest).  Runs as the autorun test, after Serial.HC.
//The host prepends a generated prelude that defines:
//  I64 hf_vf_compile_time;                 //CDate stored at offset 0x34
//                                          //of the new 0000Kernel.BIN.C
//  I64 hf_vf_kernel_size,hf_vf_kernel_crc;
//  I64 hf_vf_compiler_size,hf_vf_compiler_crc;
//Status lines start with "HFVF ".  Exit code: bit mask of failed checks
//(1=sys_compile_time, 2=kernel file, 4=compiler file), 0=all good.

I64 HfVfFile(U8 *file,I64 want_size,I64 want_crc)
{//0 if file matches size and CRC-32.
  I64 size=0,crc;
  U8 *buf=FileRead(file,&size);
  if (!buf) {
    HfPrint("HFVF MISSING %s\n",file);
    return 1;
  }
  crc=HfCrc32(buf,size);
  Free(buf);
  if (size==want_size && crc==want_crc) {
    HfPrint("HFVF FILE OK %s size=%d crc=%08X\n",file,size,crc);
    return 0;
  }
  HfPrint("HFVF FILE MISMATCH %s size=%d crc=%08X want size=%d crc=%08X\n",
	file,size,crc,want_size,want_crc);
  return 1;
}

U0 HfVerify()
{
  I64 bad=0;
  HfPrint("HFVF OS V%5.3f boot_src=%d\n",sys_os_version,sys_boot_src.u16[0]);
  if (sys_compile_time(I64)==hf_vf_compile_time) {
    HfPrint("HFVF COMPILE_TIME OK %X %D %T\n",sys_compile_time,
	  sys_compile_time,sys_compile_time);
  } else {
    HfPrint("HFVF COMPILE_TIME MISMATCH %X want %X\n",
	  sys_compile_time,hf_vf_compile_time);
    bad|=1;
  }
  if (HfVfFile("::/0000Boot/0000Kernel.BIN.C",
	hf_vf_kernel_size,hf_vf_kernel_crc))
    bad|=2;
  if (HfVfFile("::/Compiler/Compiler.BIN",
	hf_vf_compiler_size,hf_vf_compiler_crc))
    bad|=4;
  HfShot("desktop");
  HfPrint("HFVF END bad=%d\n",bad);
  hf_exit_code=bad;
}

HfVerify;
