//WS3: real keystrokes into a terminal.  Run with:
//forge.py run guest/TestOracleKeys.HC --keys
//  '11:<f7>;11.5:<f7>;12:<f8>;12.5:<shift-f7>;14:<ctrl-alt-r>;15:<f6>;17:<esc>;21:<ctrl-alt-b>'
//  --shots 16
//The host presses the keys; this checks what they did.

I64 tk_fails=0;

U0 Check(Bool cond,U8 *name)
{
  if (cond)
    HfPrint("PASS %s\n",name);
  else {
    tk_fails++;
    HfPrint("FAIL %s\n",name);
  }
}

U8 *DocText(CDoc *doc)
{
  CDocEntry *e;
  I64 size=1;
  U8 *res,*dst;
  e=doc->head.next;
  while (e!=doc) {
    if (e->type_u8==DOCT_TEXT || e->type_u8==DOCT_SONG)
      size+=StrLen(e->tag);
    else if (e->type_u8==DOCT_NEW_LINE)
      size++;
    e=e->next;
  }
  res=dst=MAlloc(size);
  e=doc->head.next;
  while (e!=doc) {
    if (e->type_u8==DOCT_TEXT || e->type_u8==DOCT_SONG) {
      StrCpy(dst,e->tag);
      dst+=StrLen(e->tag);
    } else if (e->type_u8==DOCT_NEW_LINE)
      *dst++='\n';
    e=e->next;
  }
  *dst=0;
  return res;
}

Bool DocHas(CDoc *doc,U8 *needle)
{
  U8 *st=DocText(doc);
  Bool res=ToBool(StrMatch(needle,st));
  Free(st);
  return res;
}

CTask *term=User;
F64 t0=tS;
Bool got_passage=FALSE,got_song=FALSE,got_backmask=FALSE;
U8 *st;

Sleep(300);
WinFocus(term);
HfPrint("KEYS_READY %d\n",ToI64(tS*1000));
while (tS-t0<30.0 && !(got_passage && got_song && got_backmask)) {
  if (!got_passage && DocHas(DocPut(term),"(hold to a mirror)")) {
    got_passage=TRUE;
    HfPrint("passage at %5.2fs\n",tS-t0);
  }
  if (!got_song && DocHas(DocPut(term),"<Diabolus>")) {
    got_song=TRUE;
    HfPrint("song at %5.2fs\n",tS-t0);
  }
  if (!got_backmask && music.backmask) {
    got_backmask=TRUE;
    HfPrint("backmask at %5.2fs\n",tS-t0);
  }
  Sleep(100);
}
Sleep(500);
HfShot("keys");
st=DocText(DocPut(term));
HfPrint("TERMINAL:\n%s\nEND\n",st);
Free(st);
Check(got_passage,"<SHIFT-F7> printed a backmasked passage");
Check(got_song,"<F6> + <ESC> inserted a Diabolus song");
Check(got_backmask,"<CTRL-ALT-r> turned on backmasking");
music.backmask=FALSE;
music.cur_song=NULL;

//<CTRL-ALT-b> is pressed at 21s: the Bible opens at Revelation.
while (tS<25.0)
  Sleep(100);
HfShot("bible");

CTask *notes=User("Ed(\"::/Adam/God/AdvNotes.DD\");\n");
Sleep(1500);
st=DocText(DocPut(notes));
Check(StrMatch("TRUE BACKMASKS",st)!=NULL,"AdvNotes.DD opens");
Free(st);
HfShot("advnotes");
Kill(notes);
HfPrint("TestOracleKeys: %d failed\n",tk_fails);
hf_exit_code=tk_fails;
