//WS3: The Adversary oracle and music.  forge.py run guest/TestOracle.HC --smp 4
//Every check prints PASS/FAIL to COM1; any FAIL makes hf_exit_code nonzero.

#include "::/Apps/Psalmody/Load"
#include "::/Apps/Vocabulary/Load"

I64 to_fails=0,to_passes=0;
U8 to_holy[7]={60,62,51,53,55,56,58},to_unholy[7]={59,61,51,52,54,56,57},
	to_locrian[8]={0,1,3,5,6,8,10,12},
	to_diabolus[11]={0,1,6,7,10,12,13,16,18,19,24};

U0 Check(Bool cond,U8 *name)
{
  if (cond) {
    to_passes++;
    HfPrint("PASS %s\n",name);
  } else {
    to_fails++;
    HfPrint("FAIL %s\n",name);
  }
}

U0 CheckStr(U8 *got,U8 *expect,U8 *name)
{
  if (got && !StrCmp(got,expect)) {
    to_passes++;
    HfPrint("PASS %s [%s]\n",name,got);
  } else {
    to_fails++;
    HfPrint("FAIL %s got [%s] expected [%s]\n",name,got,expect);
  }
}

U0 SeedIdx(I64 v,I64 bits)
{//Make the next GodBits(bits) return v.
  I64 i,r=0;
  for (i=0;i<bits;i++)
    if (Bt(&v,i))
      Bts(&r,bits-1-i);
  FifoU8Flush(god.fifo);
  GodBitsIns(bits,r);
}

U0 SeedMany(I64 seed)
{
  I64 i;
  FifoU8Flush(god.fifo);
  for (i=0;i<60;i++)
    GodBitsIns(24,(seed+i)*0x9E3779B1);
}

I64 VocabIdx(U8 *w)
{
  I64 i;
  for (i=0;i<god.num_words;i++)
    if (!StrCmp(god.words[i],w))
      return i;
  return -1;
}

U8 *DocText(CDoc *doc=NULL)
{//Plain text of a doc, MAlloc()ed.
  CDocEntry *e;
  I64 size=1;
  U8 *res,*dst;
  if (!doc) doc=DocPut;
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

Bool DocHas(U8 *needle,CDoc *doc=NULL)
{
  U8 *st=DocText(doc);
  Bool res=ToBool(StrMatch(needle,st));
  Free(st);
  return res;
}

Bool OnasMatch(U8 *a,U8 *b)
{//Is b's note list a's note list reversed?
  CPlayNote *na,*nb;
  I64 i,n,m,o1=4,o2=4,t1=4,t2=4,b1=4,b2=4;
  F64 l1=1.0,l2=1.0;
  Bool res=TRUE;
  n=PlayNotesNew(a,&na,music.note_map,&o1,&l1,&t1,&b1);
  m=PlayNotesNew(b,&nb,music.note_map,&o2,&l2,&t2,&b2);
  if (n!=m || !n)
    res=FALSE;
  else
    for (i=0;i<n;i++)
      if (na[i].ona!=nb[n-1-i].ona ||
	    Abs(na[i].note_len-nb[n-1-i].note_len)>0.0001)
	res=FALSE;
  Free(na);
  Free(nb);
  return res;
}

U8 *SongFile(U8 *name)
{
  U8 *st=MStrPrint("::/Apps/Psalmody/Examples/%s.HC.Z",name),
	*res=BibleFileFind(st);
  Free(st);
  return res;
}

U0 TestWords()
{
  I64 i,j;
  U8 *st;
  HfPrint("-- AdversaryWord: %d words, %d true backmasks, %d palindromes\n",
	god.num_words,god.num_backmasks,god.num_palindromes);
  Check(god.num_words>7000,"vocab loaded");
  Check(god.rev_words!=NULL && god.rev_match!=NULL,"rev tables built");
  Check(god.num_backmasks>=20,"at least 20 true backmasks in vocab");
  Check(god.num_palindromes>0,"palindromes found");

  i=VocabIdx("god");
  j=VocabIdx("dog");
  Check(i>=0 && j>=0,"god and dog in vocab");
  CheckStr(god.rev_words[i],"dog","rev_words[god]");
  Check(god.rev_match[i]==j && god.rev_match[j]==i,"god<->dog matched");
  Check(AdversaryIsTrueBackmask(i),"god is a TRUE BACKMASK");

  SeedIdx(i,17);
  Check(AdversaryWordIdx(17)==i,"seeded idx picks god");
  SeedIdx(i,17);
  CheckStr(AdversaryWordStr,"dog","AdversaryWordStr(god)");
  st=AdversaryWordDolDoc(i);
  CheckStr(st,"$$RED$$dog$$FG$$ ","AdversaryWordDolDoc(god) is red");
  Free(st);

  DocClear;
  SeedIdx(i,17);
  AdversaryWord;
  Check(DocHas("dog"),"AdversaryWord prints dog");
  Sleep(600); //Let the tritone finish.

  i=VocabIdx("evil");
  SeedIdx(i,17);
  CheckStr(AdversaryWordStr,"live","AdversaryWordStr(evil)");
  i=VocabIdx("devil");
  Check(i>=0 && AdversaryIsTrueBackmask(i),"devil is a TRUE BACKMASK");
  CheckStr(god.words[god.rev_match[i]],"lived","devil<->lived");

  i=VocabIdx("salvation");
  Check(i>=0 && !AdversaryIsTrueBackmask(i),"salvation is plain");
  st=AdversaryWordDolDoc(i);
  CheckStr(st,"noitavlas ","AdversaryWordDolDoc(salvation)");
  Free(st);

  for (i=0;i<god.num_words;i++)
    if (god.rev_match[i]==i)
      break;
  if (i<god.num_words) {
    st=AdversaryWordDolDoc(i);
    HfPrint("palindrome: %s\n",god.words[i]);
    Check(StrMatch("PURPLE",st)!=NULL,"palindrome is purple");
    Free(st);
  }
  //Old API still works.
  SeedIdx(VocabIdx("god"),17);
  CheckStr(GodWordStr,"god","GodWordStr still forward");
}

U0 TestPassage()
{
  U8 *fwd,*back,*rf;
  I64 n;
  HfPrint("-- AdversaryPassage\n");
  fwd=BibleLinesStr(1000,5);
  back=BibleLinesStr(1000,5,TRUE);
  Check(fwd && back,"BibleLinesStr");
  HfPrint("%s---\n%s",fwd,back);
  Check(StrMatch("10:3 And the sons of Gomer",fwd)!=NULL,"forward text");
  Check(StrMatch(".hamragoT dna ,htahpiR dna ,zanekhsA ;remoG fo snos eht dnA 3:01",
	back)!=NULL,"backmasked text");
  n=StrLen(fwd);
  rf=StrMirror(fwd);
  Check(n==StrLen(back) && back[n-1]=='\n' && !StrNCmp(rf+1,back,n-1),
	"backmask = lines reversed, chars reversed");
  Free(rf);
  Free(fwd);
  Free(back);

  DocClear;
  SeedIdx(999,21);
  AdversaryPassage(5);
  Check(DocHas("3:01 siseneG"),"reversed verse header");
  Check(DocHas("(hold to a mirror)"),"hold to a mirror");
  Check(DocHas(".hamragoT dna"),"passage backmasked in doc");
  //Old API still works, now with or without .Z on the CD.
  DocClear;
  SeedIdx(999,21);
  GodBiblePassage(5);
  Check(DocHas("Genesis 10:3"),"GodBiblePassage header");
  Check(DocHas("10:3 And the sons of Gomer"),"GodBiblePassage text");
}

U0 TestPlayStrRev()
{
  U8 *st,*st2,*st3,
	*hymn="5qEsCDCDqCDeEGsE4B5E4B5eC4B5sD4A5D4A";
  HfPrint("-- PlayStrRev\n");
  music.octave=4;
  music.note_len=1.0;
  st=PlayStrRev("4qCDE");		CheckStr(st,"4qEDC","rev simple");	Free(st);
  st=PlayStrRev("5eC4sB(A");		CheckStr(st,"4sAB5eC","rev octaves");	Free(st);
  st=PlayStrRev("qC(DE");		CheckStr(st,"(4qEDC","rev tie moves");	Free(st);
  st=PlayStrRev("M6/84etCDbEq.RG#");
  CheckStr(st,"M6/84q.G#RetEC#C","rev meter flats rests dots");
  Free(st);
  st=PlayStrRev("");			CheckStr(st,"","rev empty");		Free(st);
  st=PlayStrRev(hymn);
  HfPrint("hymn rev: %s\n",st);
  Check(OnasMatch(hymn,st),"hymn notes reversed exactly");
  st2=PlayStrRev(st);
  st3=PlayStrRev(st2);
  CheckStr(st3,st,"rev is an involution on its own output");
  Check(OnasMatch(st,st2),"double rev = original notes");
  Free(st);
  Free(st2);
  Free(st3);
}

U0 TestPlay()
{
  F64 t0;
  U8 *st;
  HfPrint("-- Play backmasked\n");
  music.mute++;
  music.tempo=200.0;
  t0=tS;
  Play("4qCDEFGAB");
  Check(music.play_note_num==7,"Play forward 7 notes");
  st=PlayStrRev("4qCDEFGAB");
  Play(st);
  Free(st);
  Check(music.play_note_num==7,"Play of reversed str");
  DocClear;
  music.backmask=TRUE;
  Play("4qCD","ab\0cd\0");
  music.backmask=FALSE;
  Check(music.play_note_num==2,"music.backmask Play");
  Check(DocHas("dcba"),"backmasked words reversed");
  Check(tS-t0<2.0,"fast and silent");
  music.mute--;
  MusicSettingsRst;
}

U0 TestLocrian()
{
  CPlayNote *n;
  I64 i,o=4,t=4,b=4,cnt;
  F64 l=1.0;
  HfPrint("-- Unholy (Locrian) mode\n");
  music.unholy=TRUE;
  cnt=PlayNotesNew("4ABCDEFG",&n,MusicNoteMapCur,&o,&l,&t,&b);
  music.unholy=FALSE;
  Check(cnt==7,"7 notes");
  for (i=0;i<7;i++)
    if (n[i].ona!=to_unholy[i]) {
      HfPrint("note %d ona %d expected %d\n",i,n[i].ona,to_unholy[i]);
      break;
    }
  Check(i==7,"Locrian map A->Ab B->Bb D->Db E->Eb G->Gb");
  Free(n);
  o=4;
  cnt=PlayNotesNew("4ABCDEFG",&n,MusicNoteMapCur,&o,&l,&t,&b);
  for (i=0;i<7;i++)
    if (n[i].ona!=to_holy[i])
      break;
  Check(i==7,"Holy map after toggling back");
  Free(n);
  Check(music.note_map[0]==0 && music.note_map[1]==2 && music.note_map[6]==10,
	"music.note_map never mutated");
  music.unholy=TRUE;
  music.mute++;
  music.tempo=200.0;
  Play("4CDEFG#Ab");
  Check(music.play_note_num==6,"Play in unholy mode");
  music.mute--;
  music.unholy=FALSE;
  MusicSettingsRst;
}

Bool OnasIn(U8 *st,I64 root,U8 *offsets,I64 num)
{
  CPlayNote *n;
  I64 i,j,o=4,t=4,b=4,cnt;
  F64 l=1.0;
  Bool res=TRUE;
  cnt=PlayNotesNew(st,&n,music.note_map,&o,&l,&t,&b);
  if (!cnt) res=FALSE;
  for (i=0;i<cnt;i++)
    if (n[i].ona) {
      for (j=0;j<num;j++)
	if (n[i].ona-root==offsets[j])
	  break;
      if (j==num) {
	HfPrint("bad ona %d (root %d) in %s\n",n[i].ona,root,st);
	res=FALSE;
      }
    }
  Free(n);
  return res;
}

U0 TestDiabolus()
{
  U8 *st,*st2;
  I64 i,k,n,o=4,t=4,b=4,tritones=0;
  F64 l=1.0;
  CPlayNote *notes;
  HfPrint("-- DiabolusSongStr\n");
  for (i=0;i<4;i++) {
    SeedMany(100+i);
    st=DiabolusSongStr(SONG_MODE_DIABOLUS,FALSE,i&1+1,FALSE,i>=2,3);
    HfPrint("diabolus %d: %s\n",i,st);
    Check(OnasIn(st,Note2Ona(7,3),to_diabolus,11),"diabolus notes on E F Bb B D (+tritones)");
    n=PlayNotesNew(st,&notes,music.note_map,&o,&l,&t,&b);
    for (k=1;k<n;k++)
      if (notes[k].ona && notes[k-1].ona &&
	    AbsI64(notes[k].ona-notes[k-1].ona)==6)
	tritones++;
    o=4;
    l=1.0;
    Free(notes);
    music.mute++;
    music.tempo=200.0;
    try {
      Play(st);
      Check(music.play_note_num==n,"Play parses the composer output");
    } catch {
      Fs->catch_except=TRUE;
      Check(FALSE,"Play threw on composer output");
    }
    music.mute--;
    Free(st);
  }
  Check(tritones>0,"the devil's interval shows up");
  HfPrint("tritone steps: %d\n",tritones);

  SeedMany(7);
  st=DiabolusSongStr(SONG_MODE_UNHOLY);
  HfPrint("unholy: %s\n",st);
  Check(!StrOcc(st,'#') && !StrOcc(st,'b'),"Locrian song is all white keys");
  Check(OnasIn(st,Note2Ona(2,3),to_locrian,8),"Locrian song on B Locrian");
  SeedMany(7);
  st2=DiabolusSongStr(SONG_MODE_UNHOLY,TRUE);
  HfPrint("unholy backmasked: %s\n",st2);
  Check(OnasMatch(st,st2),"Backmask checkbox reverses the song");
  Free(st);
  Free(st2);

  SeedMany(9);
  st=DiabolusSongStr(SONG_MODE_HOLY,FALSE,2,TRUE,TRUE,4);
  HfPrint("holy: %s\n",st);
  Check(StrMatch("M6/8",st)!=NULL,"six eight");
  Free(st);
  MusicSettingsRst;
}

U0 TestPsalmody()
{
  I64 psm_octave=4,n0;
  F64 psm_duration=1.0;
  U8 *file,*s0,*s1,*s2;
  PsmNote *tmpn;
  F64 t0;
  HfPrint("-- Psalmody retrograde/invert\n");
  MemSet(&psm,0,sizeof(PsmCtrl));
  psm.head.next=psm.head.last=&psm.head;
  psm.clip.next=psm.clip.last=&psm.clip;
  psm.cur_note=&psm.head;
  psm.incomplete_entry=CAlloc(sizeof(CMenuEntry));

  PsmLoadSongStr("4qC(DE",&psm_octave,&psm_duration);
  s0=PsmCvtSong;
  CheckStr(s0,"4qC(DE","psm load");
  PsmBackmask;
  s1=PsmCvtSong;
  CheckStr(s1,"(4qEDC","PsmBackmask moves the tie like PlayStrRev");
  Free(s0);
  Free(s1);
  PsmSongDel(&psm.head);
  psm.cur_note=&psm.head;

  psm_octave=4;
  psm_duration=1.0;
  PsmLoadSongStr("4qCEG",&psm_octave,&psm_duration);
  PsmInvert;
  s1=PsmCvtSong;
  CheckStr(s1,"4qC3G#F","PsmInvert around C");
  PsmInvert;
  s2=PsmCvtSong;
  CheckStr(s2,"4qCEG","invert twice");
  Free(s1);
  Free(s2);
  PsmSongDel(&psm.head);
  psm.cur_note=&psm.head;

  file=SongFile("childish");
  Check(file!=NULL,"childish.HC found");
  psm_octave=4;
  psm_duration=1.0;
  PsmLoadSong(file,&psm_octave,&psm_duration);
  psm.cur_note=psm.head.next;
  s0=PsmCvtSong;
  n0=QueCnt(&psm.head);
  HfPrint("childish: %d notes %s\n",n0,s0);
  Check(n0>20,"loaded example song");
  tmpn=psm.head.last;
  PsmBackmask;
  Check(psm.head.next==tmpn,"last note is now first");
  s1=PsmCvtSong;
  PsmBackmask;
  s2=PsmCvtSong;
  CheckStr(s2,s0,"backmask twice = original");
  Check(StrCmp(s1,s0)!=0,"backmasked differs");
  Free(s1);
  Free(s2);
  PsmInvert;
  s1=PsmCvtSong;
  HfPrint("childish inverted: %s\n",s1);
  PsmSongDel(&psm.head);
  psm.cur_note=&psm.head;
  psm_octave=4;
  psm_duration=1.0;
  PsmLoadSongStr(s1,&psm_octave,&psm_duration);
  Check(QueCnt(&psm.head)==n0,"inverted song reloads");
  music.mute++;
  music.tempo=200.0;
  Play(s1);
  music.mute--;
  Check(music.play_note_num>20,"inverted song plays");
  Free(s0);
  Free(s1);
  PsmSongDel(&psm.head);
  Free(file);

  psm_octave=4;
  psm_duration=1.0;
  psm.cur_note=&psm.head;
  PsmLoadSongStr("4sCDE",&psm_octave,&psm_duration);
  tempo_state.tempo=TEMPO_RANGE;
  tempo_state.stacatto=TEMPO_RANGE;
  t0=tS;
  PsmPlayBackwards;
  Check(!psm.playing && tS-t0<1.0,"PsmPlayBackwards");
  PsmSongDel(&psm.head);
  MusicSettingsRst;
}

U0 TestPsalmodyUI()
{
  CTask *task;
  CMenuEntry *m;
  I64 i,popups=0,n,last_ona,first_ona;
  CHashGlblVar *g;
  PsmCtrl *p;
  HfPrint("-- Psalmody Song menu\n");
  task=User("#include \"::/Apps/Psalmody/Run\";\n");
  Sleep(2000);
  m=MenuEntryFind(task->cur_menu,"Song/Backmask");
  Check(m!=NULL,"Song/Backmask menu entry");
  Check(MenuEntryFind(task->cur_menu,"Song/Invert")!=NULL,"Song/Invert menu entry");
  Check(MenuEntryFind(task->cur_menu,"Song/PlayBackwards")!=NULL,
	"Song/PlayBackwards menu entry");
//PostMsg, not PostMsgWait: the task blocks inside the pop-ups.
  PostMsg(task,MSG_KEY_DOWN_UP,',',0); //Random song: God's form pops up,
  for (i=0;i<80;i++) {			//then a SUMMON pop-up per 24 bits.
    Sleep(150);
    if (TaskValidate(task->popup_task)) {
      if (++popups==2)
	HfShot("summon");
      PostMsg(task->popup_task,MSG_KEY_DOWN_UP,CH_ESC,0);
    }
  }
  HfPrint("%d pop-ups\n",popups);
  Check(popups>=2,"Random song asked the Abyss");
  HfShot("psalmody");
  //That task compiled its own Psalmody: look at its psm.
  if (g=HashFind("psm",task->hash_table,HTT_GLBL_VAR)) {
    p=g->data_addr;
    n=QueCnt(&p->head);
    HfPrint("random song: %d notes\n",n);
    Check(n>=8,"Random song loaded into Psalmody");
    if (n) {
      last_ona=p->head.last->ona;
      PostMsgWait(task,MSG_KEY_DOWN_UP,'b',0);
      Sleep(300);
      Check(p->head.next->ona==last_ona && QueCnt(&p->head)==n,
	    "<b> backmasked the song in Psalmody");
      first_ona=p->head.next->ona;
      PostMsgWait(task,MSG_KEY_DOWN_UP,'v',0);
      Sleep(300);
      Check(p->head.next->ona==first_ona,"<v> inverts around the first note");
    }
  } else
    Check(FALSE,"psm found");
  Check(TaskValidate(task),"Psalmody survives b and v");
  PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
  Sleep(300);
  Kill(task);
}

U0 TestJukeBox()
{
  U8 *file=SongFile("prosper"),*song,*words,*rev,*ptr;
  F64 tempo=0,stac=0.9;
  I64 n=0,w=0;
  CTask *t;
  HfPrint("-- DoomBox\n");
  Check(file!=NULL,"prosper.HC found");
  song=JukeSongStr(file,&words,&tempo,&stac,&n);
  HfPrint("prosper: %d notes tempo %5.3f stacatto %5.3f\n%s\n",n,tempo,stac,song);
  Check(n>20 && Abs(tempo-3.5)<0.01,"JukeSongStr parsed the hymn and its tempo");
  ptr=words;
  while (*ptr) {
    w++;
    ptr+=StrLen(ptr)+1;
  }
  Check(w==n,"one word per note");
  rev=PlayStrRev(song);
  Check(OnasMatch(song,rev),"hymn backmask exact");
  Free(rev);
  Free(song);
  Free(words);

  music.mute++;
  jb_backmask_notes=0;
  t=Spawn(&JukeBackmask,file,"JukeBackmask",,Fs);
  Sleep(1500);
  Check(TaskValidate(t),"JukeBackmask task runs");
  Check(jb_backmask_notes==n,"JukeBackmask parsed the song");
  Check(music.play_note_num>0,"JukeBackmask is playing");
  Kill(t);
  Sleep(100);
  Check(!TaskValidate(t),"JukeBackmask killed");
  music.mute--;
  Free(file);
}

CTask *FindTitle(U8 *title)
{
  I64 c;
  CTask *t,*t0;
  for (c=0;c<mp_cnt;c++) {
    t=t0=cpu_structs[c].seth_task;
    do {
      if (!StrCmp(t->task_title,title))
	return t;
      t=t->next_task;
    } while (t!=t0);
  }
  return NULL;
}

U0 TestDoomBoxKeys()
{
  CTask *task,*song;
  HfPrint("-- DoomBox <b> key\n");
  music.mute++;
  task=User("#include \"::/Apps/Psalmody/Load\";"
	"DoomBox(\"::/Apps/Psalmody/Examples\");\n");
  BirthWait(&task->popup_task);
  Sleep(500);
  PostMsgWait(task->popup_task,MSG_KEY_DOWN_UP,0,SC_CURSOR_RIGHT);
  PostMsgWait(task->popup_task,MSG_KEY_DOWN_UP,'b',0);
  Sleep(1500);
  HfShot("doombox");
  song=FindTitle("hsidlihc");
  if (!song) song=FindTitle("thgin");
  if (!song) song=FindTitle("repsorp");
  Check(song!=NULL,"<b> spawned a backmasked song task");
  if (song)
    HfPrint("backmasked task: %s\n",song->task_title);
  PostMsgWait(task->popup_task,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
  DeathWait(&task->popup_task);
  Sleep(200);
  Check(!song || !TaskValidate(song),"song task stopped with the box");
  DeathWait(&task,TRUE);
  music.mute--;
}

U0 TestVocab()
{
  U8 *st;
  I64 i,defs=0;
  CTask *task;
  HfPrint("-- Vocabulary\n");
  st=VocabQuizPrompt("abcdef");
  HfPrint("%s\n",st);
  Check(StrMatch("fedcba",st)!=NULL,"quiz word backmasked");
  Check(StrMatch("Unscramble the backmask",st)!=NULL,"quiz prompt");
  Free(st);
  for (i=0;i<50;i++)
    if ((st=RandVocabWord) && (st=ACDDefGet(st))) {
      defs++;
      Free(st);
    }
  HfPrint("%d of 50 random words have a definition\n",defs);
  st=RandVocabWordDef;
  Check(st!=NULL,"RandVocabWordDef");
  if (st) {
    Check(ACDDefGet(st)!=NULL,"quiz word has a definition");
    st=VocabQuizPrompt(st);
    HfPrint("%s\n",st);
    Free(st);
  }
  task=User("#include \"::/Apps/Vocabulary/Load\";VocabQuiz;\n");
  Sleep(1500);
  st=DocText(DocPut(task));
  Check(StrMatch("Unscramble the backmask",st)!=NULL,"VocabQuiz runs");
  Free(st);
  HfShot("vocab");
  Kill(task);
}

U0 TestKeys()
{
  CDoc *doc=DocPut;
  HfPrint("-- F-keys and Ctrl-Alt keys\n");
  DocPutKey(doc,0,SC_F6|SCF_KEY_DESC);
  CheckStr(keydev.desc,"Cmd /Diabolus Song","F6 desc");
  DocPutKey(doc,0,SC_F6|SCF_KEY_DESC|SCF_SHIFT);
  CheckStr(keydev.desc,"Cmd /Adversary Doodle","Shift-F6 desc");
  DocPutKey(doc,0,SC_F7|SCF_KEY_DESC);
  CheckStr(keydev.desc,"Cmd /Adversary Word","F7 desc");
  DocPutKey(doc,0,SC_F7|SCF_KEY_DESC|SCF_SHIFT);
  CheckStr(keydev.desc,"Cmd /Adversary Passage","Shift-F7 desc");
  DocPutKey(doc,0,SC_F8|SCF_KEY_DESC);
  CheckStr(keydev.desc,"Cmd /God Word","F8 desc");
  DocPutKey(doc,0,SC_F8|SCF_KEY_DESC|SCF_SHIFT);
  CheckStr(keydev.desc,"Cmd /God Passage","Shift-F8 desc");
  DocPutKey(doc,0,SC_F9|SCF_KEY_DESC);
  CheckStr(keydev.desc,"Cmd /God Song","F9 desc");
  DocPutKey(doc,0,SC_F9|SCF_KEY_DESC|SCF_SHIFT);
  CheckStr(keydev.desc,"Cmd /God Doodle","Shift-F9 desc");
  DocPutKey(doc,0,SC_F1|SCF_KEY_DESC|SCF_SHIFT);
  CheckStr(keydev.desc,"Cmd /About","Shift-F1 desc");

  DocClear;
  DocPutKey(doc,0,SC_F7);
  Check(StrLen(DocText)>1,"F7 handler prints a word");
  DocClear;
  DocPutKey(doc,0,SC_F7|SCF_SHIFT);
  Check(DocHas("(hold to a mirror)"),"Shift-F7 handler prints a passage");
  DocClear;
  DocPutKey(doc,0,SC_F8);
  Check(StrLen(DocText)>1,"F8 handler prints a word");
  Sleep(600);

  CheckStr(keydev.ctrl_alt_no_shift_descs['R'-'A'],"Cmd /Backmask All Music",
	"Ctrl-Alt-R desc");
  CheckStr(keydev.ctrl_alt_shift_descs['R'-'A'],"Cmd /Unholy Mode (Locrian)",
	"Ctrl-Alt-Shift-R desc");
  CheckStr(keydev.ctrl_alt_no_shift_descs['B'-'A'],"Cmd /Bible (Revelation First)",
	"Ctrl-Alt-B desc");
  music.mute++;
  (*keydev.fp_ctrl_alt_cbs['R'-'A'])(0);
  Check(music.backmask && !music.unholy,"Ctrl-Alt-R backmask on");
  (*keydev.fp_ctrl_alt_cbs['R'-'A'])(SCF_SHIFT);
  Check(music.backmask && music.unholy,"Ctrl-Alt-Shift-R unholy on");
  MusicSettingsRst;
  Check(music.backmask && music.unholy,"MusicSettingsRst keeps the flags");
  (*keydev.fp_ctrl_alt_cbs['R'-'A'])(0);
  (*keydev.fp_ctrl_alt_cbs['R'-'A'])(SCF_SHIFT);
  Check(!music.backmask && !music.unholy,"Ctrl-Alt-R toggles back");
  Sleep(600);
  music.mute--;

  DocClear;
  TimeInsRev;
  Check(DocHas("----") && StrLen(DocText)>10,"Alt-Shift-F7 TimeInsRev");
}

U0 TestBible()
{
  CDoc *doc;
  CDocEntry *e;
  F64 t0=tS;
  HfPrint("-- Ctrl-Alt-B Bible at Revelation\n");
  doc=BibleDoc;
  e=BibleDocBook(doc);
  Check(e!=NULL,"Revelation tree found");
  if (e) {
    HfPrint("Revelation at line %d, %d books before it\n",e->y+1,65);
    Check(e->y>60,"Revelation is near the end");
    Check(!(e->de_flags&DOCEF_CHECKED_COLLAPSED),"Revelation tree opened");
  }
  DocDel(doc);
  HfPrint("BibleDoc %5.2fs\n",tS-t0);
}

U0 Showcase(U8 *elems)
{//Show the oracle on screen for a screenshot.
  music.mute++;
  DocClear;
  LBts(&Fs->display_flags,DISPLAYf_SHOW);
  WinHorz(1,TEXT_COLS-2);
  WinVert(2,TEXT_ROWS-2);
  WinToTop;
  "$$WW,1$$$$RED$$The Adversary speaks.$$FG$$  <F7> x9, seeded:\n\n";
  SeedIdx(VocabIdx("god"),17);		AdversaryWord;
  SeedIdx(VocabIdx("salvation"),17);	AdversaryWord;
  SeedIdx(VocabIdx("evil"),17);		AdversaryWord;
  SeedIdx(VocabIdx("heaven"),17);	AdversaryWord;
  SeedIdx(VocabIdx("devil"),17);	AdversaryWord;
  SeedIdx(VocabIdx("noon"),17);		AdversaryWord;
  SeedIdx(VocabIdx("deliver"),17);	AdversaryWord;
  SeedIdx(VocabIdx("angels"),17);	AdversaryWord;
  SeedIdx(VocabIdx("door"),17);		AdversaryWord;
  "\n\n$$RED$$<SHIFT-F7>:$$FG$$ ";
  SeedIdx(999,21);
  AdversaryPassage(6);
  "\n$$RED$$<SHIFT-F6>:$$FG$$\n";
  if (elems)
    Sprite(elems);
  "\n";
  Sleep(800);
  HfShot("showcase");
  music.mute--;
}

U0 TestDoodle()
{
  U8 *hex,*elems,*hx="0123456789ABCDEF";
  I64 i;
  U64 x=666;
  F64 t0=tS;
  HfPrint("-- AdversaryDoodle\n");
  WinHorz(1,24);
  WinVert(2,12);
  Sleep(100);
  hex=MAlloc(4097);
  for (i=0;i<4096;i++) {
    x=x*6364136223846793005+1442695040888963407;
    hex[i]=hx[x>>60];
  }
  hex[4096]=0;
  elems=AdversaryDoodleSprite(hex);
  Check(elems!=NULL,"hellfire sprite drawn");
  Check(!god.doodle_hell,"doodle_hell restored");
  Showcase(elems);
  Free(elems);
  Free(hex);
  HfPrint("doodle %5.2fs\n",tS-t0);
}

U0 TestSemordnilap()
{
  HfPrint("-- Semordnilap on %d cores\n",mp_cnt);
}

TestWords;
TestPassage;
TestPlayStrRev;
TestPlay;
TestLocrian;
TestDiabolus;
TestKeys;
TestBible;
TestPsalmody;
TestPsalmodyUI;
TestJukeBox;
TestDoomBoxKeys;
TestVocab;

TestSemordnilap;
#include "::/Demo/MultiCore/Semordnilap"
HfPrint("%d pairs, %d palindromes, %d words\n",
	sem_num_pairs,sem_num_palindromes,sem_num_words);
Check(sem_num_pairs>10,"Semordnilap found pairs");
Check(SemordnilapPair("evil","live"),"Bible: evil/live");
Check(SemordnilapPair("god","dog"),"Bible: god/dog");
Check(SemordnilapPair("lived","devil"),"Bible: lived/devil");
I64 to_i;
for (to_i=0;to_i<mp_cnt;to_i++)
  Check(sem_cpu_cnts[to_i]>0,"every core found some");

TestDoodle;
HfShot("oracle");

HfPrint("TestOracle: %d passed, %d failed\n",to_passes,to_fails);
hf_exit_code=to_fails;
