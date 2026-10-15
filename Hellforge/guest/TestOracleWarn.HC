//WS3: recompile every WS3 file in a throwaway terminal with the boot-time
//warnings on (paren + dup types) and fail on any WARNING or ERROR.

U8 *DocText(CDoc *doc)
{
  CDocEntry *e;
  I64 size=1;
  U8 *res,*dst;
  e=doc->head.next;
  while (e!=doc) {
    if (e->type_u8==DOCT_TEXT)
      size+=StrLen(e->tag);
    else if (e->type_u8==DOCT_NEW_LINE)
      size++;
    e=e->next;
  }
  res=dst=MAlloc(size);
  e=doc->head.next;
  while (e!=doc) {
    if (e->type_u8==DOCT_TEXT) {
      StrCpy(dst,e->tag);
      dst+=StrLen(e->tag);
    } else if (e->type_u8==DOCT_NEW_LINE)
      *dst++='\n';
    e=e->next;
  }
  *dst=0;
  return res;
}

U8 *files[11]={
  "::/Adam/ASnd.HC", //Same order as MakeAdam.
  "::/Adam/God/GodExt.HC",
  "::/Adam/DolDoc/DocPutKey.HC",
  "::/Adam/God/GodBible.HC",
  "::/Adam/God/HolySpirit.HC",
  "::/Adam/God/GodSong.HC",
  "::/Adam/God/GodDoodle.HC",
  "::/HomeKeyPlugIns.HC",
  "::/Apps/Psalmody/Load.HC",
  "::/Apps/Vocabulary/Load.HC",
  "::/Demo/MultiCore/Semordnilap.HC"
};
CTask *t=User;
I64 i,warns=0,errs=0;
U8 *st,*ptr;
XTalkWait(t,"Option(OPTf_WARN_PAREN,ON);Option(OPTf_WARN_DUP_TYPES,ON);\n");
for (i=0;i<11;i++) {
  st=MStrPrint("#include \"%s\";\n",files[i]);
  XTalkWait(t,st);
  Free(st);
  HfPrint("compiled %s\n",files[i]);
}
st=DocText(DocPut(t));
ptr=st;
while (ptr=StrMatch("WARNING",ptr)) {
  warns++;
  ptr++;
}
ptr=st;
while (ptr=StrMatch("TEMPTATION",ptr)) { //WS1's name for a warning.
  warns++;
  ptr++;
}
ptr=st;
while (ptr=StrMatch("ERROR",ptr)) {
  errs++;
  ptr++;
}
ptr=st;
while (ptr=StrMatch("BLASPHEMY",ptr)) { //WS1's name for an error.
  errs++;
  ptr++;
}
HfPrint("TERMINAL:\n%s\nEND\nwarnings=%d errors=%d\n",st,warns,errs);
Free(st);
//The recompiled ASnd and GodBible pointed Ctrl-Alt-R/B at this terminal.
CtrlAltCBSet('R',&CtrlAltR,"Cmd /Backmask All Music",
	"Cmd /Unholy Mode (Locrian)");
CtrlAltCBSet('B',&CtrlAltB,"Cmd /Bible (Revelation First)");
Kill(t);
hf_exit_code=warns+errs;
