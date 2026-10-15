//Hellforge in-guest bootstrap (driven by 'forge.py bootstrap').
//Runs as the autorun test (see WRAPPER in forge.py), after Serial.HC.
//
//Does what ::/Misc/DoDistro.HC + ::/Adam/Opt/Boot/BootDVDIns.HC do
//(In(STD_DISTRO_DVD_CFG); MakeAll; Move(Kernel.BIN.Z,0000Kernel.BIN.C)),
//but on a writable drive (the RAM drive B: by default) because the
//boot CD (T:) is read-only.  Results go back to the host as framed
//HFDUMP blocks; status lines start with "HFBS ".
//
//The host prepends a generated prelude that defines:
//  U8 hf_bs_drv;          //work drive letter, e.g. 'B'
//  U8 *hf_bs_cfg;         //answers to ::/Kernel/KCfg.HC prompts
//  U8 *hf_bs_trees[];     //NULL-terminated list of dirs to copy from ::/
//  Bool hf_bs_bootdvdins; //TRUE: call BootDVDIns() itself (no err counts)

#define HF_BS_EXIT_OK		0
#define HF_BS_EXIT_CMP		10	//Compiler.PRJ had errors
#define HF_BS_EXIT_KERNEL	11	//Kernel.PRJ had errors
#define HF_BS_EXIT_MISSING	12	//an expected output file is missing
#define HF_BS_EXIT_COPY		13	//could not stage the sources

I64 HfBsMs()
{
  return ToI64(tS*1000);
}

U8 *HfBsPath(U8 *rel)
{//"B:/rel"
  return MStrPrint("%C:/%s",hf_bs_drv,rel);
}

Bool HfBsDump(U8 *name,U8 *rel1,U8 *rel2=NULL)
{//Dump the first of rel1/rel2 that exists on the work drive.
  U8 *p=HfBsPath(rel1);
  Bool res=FALSE;
  if (!FileFind(p,,FUF_Z_OR_NOT_Z) && rel2) {
    Free(p);
    p=HfBsPath(rel2);
  }
  if (FileFind(p,,FUF_Z_OR_NOT_Z)) {
    HfPrint("HFBS FILE %s %s\n",name,p);
    res=HfDumpFile(p,name);
  } else
    HfPrint("HFBS MISSING %s %s\n",name,rel1);
  Free(p);
  return res;
}

U0 HfBootstrap()
{
  I64 i,e_cmp=-1,e_kern=-1,cnt;
  U8 *src,*dst,*root=HfBsPath("");
  HfPrint("HFBS BEGIN %d drv=%C boot=%C\n",HfBsMs,hf_bs_drv,
	Drv2Let(Let2Drv(':')));
  if (!Drv(hf_bs_drv) || !DrvIsWritable(hf_bs_drv)) {
    HfPrint("HFBS ERROR drive %C not writable\n",hf_bs_drv);
    hf_exit_code=HF_BS_EXIT_COPY;
    goto bs_done;
  }
  for (i=0;hf_bs_trees[i];i++) {
    src=MStrPrint("::/%s",hf_bs_trees[i]);
    dst=HfBsPath(hf_bs_trees[i]);
    DelTree(dst);
    cnt=CopyTree(src,dst);
    HfPrint("HFBS COPY %s -> %s files=%d %d\n",src,dst,cnt,HfBsMs);
    Free(src);
    Free(dst);
  }
  dst=HfBsPath("0000Boot");
  DirMk(dst);
  Free(dst);
  if (!FileFind(src=HfBsPath("Kernel/Kernel.PRJ"),,FUF_Z_OR_NOT_Z) ||
	!FileFind(dst=HfBsPath("Compiler/Compiler.PRJ"),,FUF_Z_OR_NOT_Z)) {
    HfPrint("HFBS ERROR sources not staged\n");
    hf_exit_code=HF_BS_EXIT_COPY;
    goto bs_done;
  }
  Free(src);
  Free(dst);
  Cd(root);

  if (hf_bs_bootdvdins) {
//Exactly ::/Misc/DoDistro.HC: In(STD_DISTRO_DVD_CFG); BootDVDIns;
    In(hf_bs_cfg);
    BootDVDIns(hf_bs_drv);
    e_cmp=e_kern=0;
    HfPrint("HFBS BOOTDVDINS done %d\n",HfBsMs);
  } else {
//Same steps as BootDVDIns()/MakeAll(), but keeping the error counts.
    HfPrint("HFBS CMP_BEGIN Compiler %d\n",HfBsMs);
    e_cmp=Cmp("/Compiler/Compiler","Compiler",,':');
    HfPrint("HFBS CMP_END Compiler errs=%d %d\n",e_cmp,HfBsMs);
    if (e_cmp) {
      hf_exit_code=HF_BS_EXIT_CMP;
      goto bs_done;
    }
    Cd(root);
//Answers ::/Kernel/KCfg.HC (run from #exe in Kernel.PRJ) via StdIn.
    In(hf_bs_cfg);
    HfPrint("HFBS CMP_BEGIN Kernel %d\n",HfBsMs);
    e_kern=Cmp("/Kernel/Kernel","Kernel",,':');
    HfPrint("HFBS CMP_END Kernel errs=%d %d\n",e_kern,HfBsMs);
    if (e_kern) {
      hf_exit_code=HF_BS_EXIT_KERNEL;
      goto bs_done;
    }
    Cd(root);
    Move("/Kernel/Kernel.BIN.Z","/0000Boot/0000Kernel.BIN.C");
  }
  Cd(root);

  HfPrint("HFBS DUMP_BEGIN %d\n",HfBsMs);
  if (!HfBsDump("0000Boot/0000Kernel.BIN.C","0000Boot/0000Kernel.BIN.C"))
    hf_exit_code=HF_BS_EXIT_MISSING;
  if (!HfBsDump("Compiler/Compiler.BIN","Compiler/Compiler.BIN.Z",
	"Compiler/Compiler.BIN"))
    hf_exit_code=HF_BS_EXIT_MISSING;
  if (!HfBsDump("Compiler/Compiler.MAP","Compiler/Compiler.MAP.Z",
	"Compiler.MAP.Z"))
    hf_exit_code=HF_BS_EXIT_MISSING;
  if (!HfBsDump("Kernel/Kernel.MAP","Kernel/Kernel.MAP.Z","Kernel.MAP.Z"))
    hf_exit_code=HF_BS_EXIT_MISSING;
  HfPrint("HFBS DUMP_END %d\n",HfBsMs);
bs_done:
  HfPrint("HFBS END code=%d cmp_errs=%d kernel_errs=%d %d\n",
	hf_exit_code,e_cmp,e_kern,HfBsMs);
  Free(root);
}

HfBootstrap;
