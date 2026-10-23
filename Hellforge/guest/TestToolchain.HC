//Hellforge toolchain test (forge.py run Hellforge/guest/TestToolchain.HC).
//Checks the image mkiso builds, from inside the guest:
//  * .Z layout: ACWords.DATA.Z (AutoComplete's dictionary words need that
//    exact name), ACDefs.DATA plain (FOpen()ed), CT_NONE .Z files.
//  * the dictionary finds definitions: ACWords/ACDefs.DATA are whole (the
//    archive's had lost their 0x05 bytes, and only 3,636 of 95,293 words
//    found a definition, none of the ones checked here).
//  * every sprite bin of every .HC/.DD file is sound, walked with the OS's
//    own SpriteElemSize() (--patch-broken-bins, the default for run), with
//    sane numbers: no mesh triangle names a vertex past its mesh's list
//    (Pick3D's shifted mesh kills QEMU-WHPX), no huge coordinates.
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

#define TC_NUM_MAX	0x100000 //mkiso.SPT_NUM_MAX

Bool TcI32sOk(I32 *p,I64 n)
{//Coordinates and sizes of a sound sprite are small.
  while (n-->0) {
    if (!(-TC_NUM_MAX<=*p<=TC_NUM_MAX))
      return FALSE;
    p++;
  }
  return TRUE;
}

Bool TcMeshOk(CD3I32 *p,I64 vertices,I64 tris)
{//Gr3Mesh() indexes p[] with every triangle's vertex numbers.
  CMeshTri *tri=p+vertices;
  I64 i,j;
  if (!TcI32sOk(p,3*vertices))
    return FALSE;
  for (i=0;i<tris;i++,tri++)
    for (j=0;j<3;j++)
      if (!(0<=tri->nums[j]<vertices))
	return FALSE;
  return TRUE;
}

Bool TcElemSane(U8 *e)
{//The numbers in the element at e (same rule as mkiso.sprite_ok()).
  CSprite *g=e-offset(CSprite.start);
  I32 *p=e+1; //The I32s after the type byte
  switch (g->type&SPG_TYPE_MASK) {
    case SPT_THICK:
      return TcI32sOk(p,1);
    case SPT_PLANAR_SYMMETRY:
    case SPT_LINE:
    case SPT_RECT:
    case SPT_ROTATED_RECT:
    case SPT_ELLIPSE:
    case SPT_BITMAP:
    case SPT_ARROW:
      return TcI32sOk(p,4);
    case SPT_POLYGON:
      return TcI32sOk(p,4) && TcI32sOk(&g->pwhas.sides,1);
    case SPT_SHIFT:
    case SPT_PT:
    case SPT_FLOOD_FILL:
    case SPT_FLOOD_FILL_NOT:
    case SPT_TEXT:
    case SPT_TEXT_BOX:
    case SPT_TEXT_DIAMOND:
      return TcI32sOk(p,2);
    case SPT_CIRCLE:
      return TcI32sOk(p,3);
    case SPT_POLYPT:
      return TcI32sOk(&g->npu.x,2);
    case SPT_POLYLINE:
      return TcI32sOk(&g->nu.u,2*g->nu.num);
    case SPT_BSPLINE2...SPT_BSPLINE3_CLOSED:
      return TcI32sOk(&g->nu.u,3*g->nu.num);
    case SPT_MESH:
      return TcMeshOk(&g->mu.u,g->mu.vertex_cnt,g->mu.tri_cnt);
    case SPT_SHIFTABLE_MESH:
      return TcI32sOk(p,3) &&
	    TcMeshOk(&g->pmu.u,g->pmu.vertex_cnt,g->pmu.tri_cnt);
  }
  return TRUE;
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
    if (off+n>max) {
      why=3;
      break;
    }
    if (!TcElemSane(d+off)) {
      why=6; //shifted numbers: huge coordinates, mesh vertex past the list
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

U0 TcACDef(U8 *word,U8 *def)
{//The dictionary's first definition of word starts with def.
  U8 *st=ACDDefGet(word);
  if (st) {
    HfPrint("TC ac: %s: %s\n",word,st);
    if (StrNCmp(st,def,StrLen(def)))
      TcFail("ACDDefGet(\"%s\") is \"%s\", not \"%s...\"",word,st,def);
    Free(st);
  } else
    TcFail("ACDDefGet(\"%s\") found no definition",word);
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
  else if (acd.has_words) {
//Blocks 363, 931 and 1482 of the 1,611 in ACDefs.DATA.
    TcACDef("Devil","The Evil One; Satan");
    TcACDef("Pandemonium","The great hall or council chamber of demons");
    TcACDef("Tritone","A superfluous or augmented fourth.");
  }
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
