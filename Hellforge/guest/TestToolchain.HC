//Hellforge toolchain test (forge.py run Hellforge/guest/TestToolchain.HC).
//Checks the image mkiso builds, from inside the guest:
//  * .Z layout: ACWords.DATA.Z (AutoComplete's dictionary words need that
//    exact name), ACDefs.DATA plain (FOpen()ed), CT_NONE .Z files.
//  * every sprite bin of every .HC/.DD file is sound, walked with the OS's
//    own SpriteElemSize() (--patch-broken-bins, the default for run).
//  * damaged DolDoc files load without "Bin Not Found" stalls.
//  * a .GR picture (not DolDoc) reads back whole: GRRead() of the damaged
//    StadiumBG.GR hangs, so the patch makes it a blank picture.
//  * with the suite's --add arguments, .Z overlays replace their file:
//    --add <this file>:Doc/Glossary.DD.Z --add <this file>:Tmp/HfAddZ.HC.Z

I64 tc_bad=0;

U0 TcFail(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("TCFAIL %s\n",st);
  Free(st);
  tc_bad++;
}

I64 TcSpriteLen(U8 *d,I64 max,I64 *_why=NULL)
{//Bytes up to and including SPT_END, or -1 if d is not a sound sprite
//within max bytes.  Element sizes come from the OS's SpriteElemSize().
  I64 off=0,t,n,why=5; //5: no SPT_END
  while (off<max) {
    t=d[off]&SPG_TYPE_MASK;
    if (!t)
      return off+1;
    if (t>=SPT_TYPES_NUM) {
      why=2; //unknown element type
      break;
    }
    if (off+sprite_elem_base_sizes[t]>max) {
      why=3; //element cut off
      break;
    }
    n=SpriteElemSize(d+off-offset(CSprite.start));
    if (n<sprite_elem_base_sizes[t]) {
      why=4; //negative count
      break;
    }
    off+=n;
  }
  if (_why) *_why=why;
  return -1;
}

I64 TcScanFile(U8 *name,I64 *_bins)
{//Walk the bin tail the way DocLoad() does and check each sprite bin.
  I64 size=0,bad=0,len,why;
  U8 *buf=FileRead(name,&size),*src,*end;
  U32 *h;
  if (!buf)
    return 0;
  end=buf+size;
  src=buf+StrLen(buf)+1;
  while (src+16<=end) {
    h=src;
    src+=16;
    *_bins+=1;
    if (src+h[2]>end) {
      TcFail("%s bin %d: size %d runs past the end of the file",name,h[0],h[2]);
      bad++;
      break;
    }
    why=1; //SPT_END before the last byte
    len=TcSpriteLen(src,h[2],&why);
    if (len!=h[2]) {
      TcFail("%s bin %d: malformed sprite (reason %d)",name,h[0],why);
      bad++;
    }
    src+=h[2];
  }
  Free(buf);
  return bad;
}

U0 TcSprites()
{
  CDirEntry *tmpde=FilesFind("::/*",FUF_RECURSE|FUF_FLATTEN_TREE|FUF_JUST_FILES),
	*tmpde1=tmpde;
  I64 files=0,bins=0,bad=0,len;
  F64 t0=tS;
  while (tmpde) {
    if (FilesFindMatch(tmpde->name,FILEMASK_DD)) {
      files++;
      bad+=TcScanFile(tmpde->full_name,&bins);
    }
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  HfPrint("TC sprites: %d files, %d bins, %d bad (%5.1fs)\n",files,bins,bad,tS-t0);
  if (files<300 || bins<100)
    TcFail("sprite scan saw too little: %d files, %d bins",files,bins);
  len=TcSpriteLen(gr.empty_sprite,4096);
  HfPrint("TC gr.empty_sprite: %d bytes\n",len);
  if (len<1)
    TcFail("gr.empty_sprite is not a sound sprite");
}

U0 TcDocLoad(U8 *name)
{//Loads with no lost bins: no DOCT_ERROR, no 3 s "Bin Not Found" stall.
  F64 t0=tS,dt;
  CDoc *doc;
  CDocEntry *doc_e;
  I64 errs=0,sprites=0;
  if (!FileFind(name,,FUF_Z_OR_NOT_Z)) {
    TcFail("%s missing",name);
    return;
  }
  doc=DocRead(name);
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_ERROR)
      errs++;
    else if (doc_e->type_u8==DOCT_SPRITE)
      sprites++;
    doc_e=doc_e->next;
  }
  DocDel(doc);
  dt=tS-t0;
  HfPrint("TC load %s: %d sprites, %d errors, %5.2fs\n",name,sprites,errs,dt);
  if (errs || dt>2.5)
    TcFail("%s: %d DolDoc errors, %5.2fs to load",name,errs,dt);
}

U0 TcAutoComplete()
{
  F64 t0=tS;
  while (!Bt(&sys_run_level,RLf_AUTO_COMPLETE) && tS-t0<30.0)
    Sleep(100);
  HfPrint("TC ac: ready=%d has_words=%d has_defs=%d num_words=%d "
	"words_Z=%d defs_plain=%d\n",
	Bt(&sys_run_level,RLf_AUTO_COMPLETE),acd.has_words,acd.has_defs,
	acd.num_words,FileFind(ACD_WORD_FILENAME),FileFind(ACD_DEF_FILENAME));
  if (!acd.has_words || !FileFind(ACD_WORD_FILENAME))
    TcFail("no %s: AutoComplete has no dictionary words",ACD_WORD_FILENAME);
  if (!acd.has_defs || !FileFind(ACD_DEF_FILENAME))
    TcFail("%s is not stored plain (FOpen() needs it)",ACD_DEF_FILENAME);
}

U0 TcAttr(U8 *name,Bool compressed)
{
  CDirEntry de;
  if (!FileFind(name,&de)) {
    TcFail("%s missing",name);
    return;
  }
  HfPrint("TC attr %s: %X\n",name,de.attr);
  if (!(de.attr&RS_ATTR_COMPRESSED)!=!compressed)
    TcFail("%s: attr %X, expected compressed=%d",name,de.attr,compressed);
  Free(de.full_name);
}

U0 TcGR()
{//GRRead() of a .GR picture: mkiso must not treat it as DolDoc (that used
//to cut it to 1 byte), and --patch-broken-bins must make it readable.
  I64 size=0;
  U8 *buf=FileRead("::/Demo/Games/Stadium/StadiumBG.GR",&size);
  CDC *dc;
  Free(buf);
  HfPrint("TC gr: StadiumBG.GR %d bytes\n",size);
  if (size<4000)
    TcFail("StadiumBG.GR cut down to %d bytes in the image",size);
  else if (dc=GRRead("::/Demo/Games/Stadium/StadiumBG")) {
    HfPrint("TC gr: %dx%d\n",dc->width,dc->height);
    if (dc->width!=641 || dc->height!=473)
      TcFail("StadiumBG.GR reads as %dx%d",dc->width,dc->height);
    DCDel(dc);
  } else
    TcFail("GRRead(StadiumBG) failed");
}

U0 TcOverlay(U8 *name)
{
  I64 size=0;
  U8 *buf=NULL;
  try {
    buf=FileRead(name,&size);
  } catch {
    Fs->catch_except=TRUE;
    TcFail("FileRead(%s) threw: an --add'ed file stored raw under a .Z name",name);
    return;
  }
  HfPrint("TC overlay %s: %d bytes\n",name,size);
  if (!buf || StrNCmp(buf,"//Hellforge toolchain test",26))
    TcFail("%s does not hold the --add'ed file",name);
  Free(buf);
}

U0 TcOverlays()
{
  CDirEntry *tmpde,*tmpde1;
  I64 n=0;
  if (!FileFind("::/Tmp/HfAddZ.HC.Z")) {
    HfPrint("TC overlays: skipped (run with the suite's --add arguments)\n");
    return;
  }
  TcOverlay("::/Tmp/HfAddZ.HC.Z");
  TcOverlay("::/Doc/Glossary.DD.Z");
  tmpde=tmpde1=FilesFind("::/Doc/Glossary.DD*");
  while (tmpde) {
    n++;
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  HfPrint("TC overlays: %d Glossary.DD entries\n",n);
  if (n!=1)
    TcFail("%d ::/Doc/Glossary.DD* entries, expected 1",n);
}

TcAttr("::/Doc/StandBy.DD.Z",TRUE);
TcAttr("::/0000Boot/0000Kernel.BIN.C",FALSE);
TcAttr("::/Adam/AutoComplete/ACDefs.DATA",FALSE);
TcAttr("::/Adam/AutoComplete/ACWords.DATA.Z",TRUE);
TcAutoComplete;
TcOverlays;
TcDocLoad("::/Adam/AMouse.HC");
TcDocLoad("::/Demo/Graphics/Extents.HC");
TcDocLoad("::/Demo/DolDoc/DemoDoc.DD");
TcDocLoad("::/Doc/HelpIndex.DD");
TcDocLoad("::/PersonalMenu.DD");
TcSprites;
TcGR; //Last: on a bad image GRRead() may never return.
HfPrint("TC_BAD %d\n",tc_bad);
hf_exit_code=tc_bad;
