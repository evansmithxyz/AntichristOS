//WS3 adversarial review: independent checks of The Adversary.
//forge.py run Hellforge/guest/TestOracleAdv.HC   (1 core on purpose)
//1) The refactored Play() parser vs the V5.03 one, on every Play("...")
//   literal in the tree.  2) PlayStrRev() is an exact retrograde on all
//   of them.  3) Holy-mode songs are bit-for-bit the V5.03 GodSongStr().
//4) Edge cases: Psalmody invert range, meters under backmask, Bible end,
//   vocab table symmetry, integer tempo in DoomBox, 1-core Semordnilap.

#include "::/Apps/Psalmody/Load"

I64 ta_fails=0,ta_passes=0;

U0 Check(Bool cond,U8 *name)
{
  if (cond) {
    ta_passes++;
    HfPrint("PASS %s\n",name);
  } else {
    ta_fails++;
    HfPrint("FAIL %s\n",name);
  }
}

U0 CheckStr(U8 *got,U8 *expect,U8 *name)
{
  if (got && !StrCmp(got,expect)) {
    ta_passes++;
    HfPrint("PASS %s [%s]\n",name,got);
  } else {
    ta_fails++;
    HfPrint("FAIL %s got [%s] expected [%s]\n",name,got,expect);
  }
}

#define TA_MAX	4096
I64 old_onas[TA_MAX];
F64 old_lens[TA_MAX];
Bool old_ties[TA_MAX];

I64 OldPlayParse(U8 *st)
{//V5.03 Play() parse loop, verbatim minus the sound and the sleeping.
  U8 *last_st;
  I64 note,octave,ona,n=0;
  Bool tie;
  music.octave=4;
  music.note_len=1.0;
  music.meter_top=4;
  music.meter_bottom=4;
  while (*st) {
    tie=FALSE;
    do {
      last_st=st;
      if (*st=='(') {
	tie=TRUE;
	st++;
      } else {
	st=MusicSetMeter(st);
	st=MusicSetOctave(st);
	st=MusicSetNoteLen(st);
      }
    } while (st!=last_st);
    if (!*st) break;
    note=*st++-'A';
    if (note<7) {
      note=music.note_map[note];
      octave=music.octave;
      if (*st=='b') {
	note--;
	if (note==2)
	  octave--;
	st++;
      } else if (*st=='#') {
	note++;
	if (note==3)
	  octave++;
	st++;
      }
      ona=Note2Ona(note,octave);
    } else
      ona=0;
    if (n<TA_MAX) {
      old_onas[n]=ona;
      old_lens[n]=music.note_len;
      old_ties[n]=tie;
    }
    n++;
  }
  return n;
}

I64 NewParse(U8 *st,CPlayNote **_notes)
{
  I64 octave=4,top=4,bottom=4;
  F64 note_len=1.0;
  return PlayNotesNew(st,_notes,music.note_map,&octave,&note_len,
	&top,&bottom);
}

Bool Stray(U8 *st)
{//Chars V5.03 Play() reads out of bounds (below 'A' and not a token).
  I64 ch;
  while (ch=*st++)
    if (ch<'A' && !('0'<=ch<='9') && ch!='(' && ch!='#' &&
	  ch!='.' && ch!='/')
      return TRUE;
  return FALSE;
}

I64 ta_strs=0,ta_notes=0,ta_parse_bad=0,ta_rev_bad=0,ta_inv_bad=0,
	ta_stray=0,ta_lens_bad=0;

U0 PlayStrCheck(U8 *st,U8 *where)
{
  CPlayNote *a,*b,*c;
  I64 i,n,nb,nc;
  U8 *r,*rr;
  Bool bad;
  if (Stray(st)) {
    ta_stray++;
    return;
  }
  ta_strs++;
//1) Old parser == new parser.
  n=OldPlayParse(st);
  if (n>TA_MAX) return;
  if (NewParse(st,&a)!=n)
    bad=TRUE;
  else {
    bad=FALSE;
    for (i=0;i<n;i++)
      if (a[i].ona!=old_onas[i] || a[i].note_len!=old_lens[i] ||
	    a[i].tie!=old_ties[i])
	bad=TRUE;
  }
  if (bad) {
    ta_parse_bad++;
    HfPrint("PARSE MISMATCH %s [%s]\n",where,st);
  }
  ta_notes+=n;
//2) PlayStrRev() gives the notes in reverse order with ties moved.
  music.octave=4;
  music.note_len=1.0;
  music.meter_top=4;
  music.meter_bottom=4;
  r=PlayStrRev(st);
  nb=NewParse(r,&b);
  bad=nb!=n;
  if (!bad)
    for (i=0;i<n;i++) {
      if (b[i].ona!=a[n-1-i].ona)
	bad=TRUE;
      if (Abs(b[i].note_len-a[n-1-i].note_len)>0.000001) {
	bad=TRUE;
	ta_lens_bad++;
      }
      if (i<n-1 && b[i].tie!=a[n-2-i].tie)
	bad=TRUE;
    }
  if (bad) {
    ta_rev_bad++;
    HfPrint("REV MISMATCH %s [%s] -> [%s]\n",where,st,r);
  }
//3) Twice reversed = the same notes.
  music.octave=4;
  music.note_len=1.0;
  rr=PlayStrRev(r);
  nc=NewParse(rr,&c);
  bad=nc!=n;
  if (!bad)
    for (i=0;i<n;i++)
      if (c[i].ona!=a[i].ona ||
	    Abs(c[i].note_len-a[i].note_len)>0.000001 ||
	    i<n-1 && c[i].tie!=a[i].tie)
	bad=TRUE;
  if (bad) {
    ta_inv_bad++;
    HfPrint("REVREV MISMATCH %s [%s] -> [%s]\n",where,st,rr);
  }
  Free(a);
  Free(b);
  Free(c);
  Free(r);
  Free(rr);
}

U0 FilePlayStrs(U8 *name)
{//Every Play("...") literal in a file (plain-text scan).
  U8 *buf=FileRead(name),*ptr,*end,*st;
  I64 l;
  if (!buf) return;
  ptr=buf;
  while (ptr=StrFind("Play(\"",ptr)) {
    ptr+=6;
    end=ptr;
    while (*end && *end!='\"' && *end!='\\' && *end!='\n')
      end++;
    if (*end=='\"') {
      l=end-ptr;
      st=MAlloc(l+1);
      MemCpy(st,ptr,l);
      st[l]=0;
      PlayStrCheck(st,name);
      Free(st);
    }
    ptr=end;
  }
  Free(buf);
}

U0 TreePlayStrs(U8 *mask)
{
  CDirEntry *tmpde,*tmpde1;
  tmpde=tmpde1=FilesFind(mask,FUF_RECURSE|FUF_JUST_FILES);
  while (tmpde) {
    FilePlayStrs(tmpde->full_name);
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
}

U0 TestPlayParser()
{
  CPlayNote *a;
  I64 n;
  U8 old_mute=music.mute;
  HfPrint("-- Play() parser regression over the tree\n");
  TreePlayStrs("::/Apps/*.HC*");
  TreePlayStrs("::/Demo/*.HC*");
  TreePlayStrs("::/Misc/*.HC*");
  TreePlayStrs("::/Adam/*.HC*");
  HfPrint("%d strs, %d notes, %d skipped (stray chars)\n",
	ta_strs,ta_notes,ta_stray);
  Check(ta_strs>=50,"found lots of Play() strs");
  Check(!ta_parse_bad,"new parser == V5.03 parser on every str");
  Check(!ta_rev_bad,"PlayStrRev exact retrograde on every str");
  Check(!ta_lens_bad,"PlayStrRev durations exact");
  Check(!ta_inv_bad,"PlayStrRev twice = original on every str");

  n=NewParse("4qC D",&a);
  Check(n==3 && !a[1].ona && a[2].ona==Note2Ona(5,4),
	"stray char is a rest, not an out-of-bounds read");
  Free(a);
  n=NewParse("",&a);
  Check(!n,"empty str");
  Free(a);
  Check(PlayStrRev(NULL)==NULL,"PlayStrRev(NULL)");

  music.mute=TRUE;
  music.tempo=200.0;
  music.backmask=TRUE;
  Play("4eCDEFG");
  Check(music.play_note_num==5,"Play backmasked counts notes");
  music.backmask=FALSE;
  music.unholy=TRUE;
  Play("4eCDEFG");
  Check(music.play_note_num==5,"Play unholy counts notes");
  music.unholy=FALSE;
  music.mute=old_mute;
  MusicSettingsRst;
}

//V5.03 GodSongStr() body, verbatim (minus the PopUpForm).
U0 OldInsNote(CMakeSongSettings *mss,U8 *buf,I64 k,I64 *j)
{
  if (!k && mss->rests) {
    buf[*j]='R';
    *j+=1;
  } else {
    k/=2;
    if (k<3) {
      if (mss->octave_state!=mss->octave) {
	mss->octave_state=mss->octave;
	buf[*j]=mss->octave_state+'0';
	*j+=1;
      }
      if (!k)
	buf[*j]='G';
      else
	buf[*j]=k-1+'A';
      *j+=1;
    } else {
      if (mss->octave_state!=mss->octave+1) {
	mss->octave_state=mss->octave+1;
	buf[*j]=mss->octave_state+'0';
	*j+=1;
      }
      buf[*j]=k-1+'A';
      *j+=1;
    }
  }
}

U8 *OldSongStr(CMakeSongSettings *_mss)
{
  CMakeSongSettings mss;
  U8 *buf;
  I64 i,j=0,k,n,k2,duration,last_duration=-1,len;
  MemCpy(&mss,_mss,sizeof(mss));
  buf=CAlloc(256);
  music.octave=mss.octave=ClampI64(mss.octave,1,7);
  mss.octave_state=mss.octave+1;
  buf[j++]='0'+mss.octave_state;
  if (mss.six_eight) {
    len=6;
    buf[j++]='M';
    buf[j++]='6';
    buf[j++]='/';
    buf[j++]='8';
  } else
    len=8;
  for (i=0;i<len;i++) {
    n=GodBits(8);
    if (mss.complexity==2)
      duration=god_complex_songs[n%9];
    else if (mss.complexity==1)
      duration=god_normal_songs[n%5];
    else
      duration=god_simple_songs[n%5];
    switch (duration) {
      case DUR_8_8:
	if (last_duration!=DUR_8_8)
	  buf[j++]='e';
	OldInsNote(&mss,buf,GodBits(4),&j);
	OldInsNote(&mss,buf,GodBits(4),&j);
	break;
      case DUR_8DOT_16:
	buf[j++]='e';
	buf[j++]='.';
	OldInsNote(&mss,buf,GodBits(4),&j);
	buf[j++]='s';
	OldInsNote(&mss,buf,GodBits(4),&j);
	duration=DUR_16_16_16_16;
	break;
      case DUR_3_3_3:
	if (last_duration!=DUR_3_3_3) {
	  buf[j++]='e';
	  buf[j++]='t';
	}
	OldInsNote(&mss,buf,GodBits(4),&j);
	OldInsNote(&mss,buf,GodBits(4),&j);
	OldInsNote(&mss,buf,GodBits(4),&j);
	break;
      case DUR_8_16_16:
	if (last_duration!=DUR_8_8)
	  buf[j++]='e';
	OldInsNote(&mss,buf,GodBits(4),&j);
	buf[j++]='s';
	OldInsNote(&mss,buf,GodBits(4),&j);
	OldInsNote(&mss,buf,GodBits(4),&j);
	duration=DUR_16_16_16_16;
	break;
      case DUR_16_16_8:
	if (last_duration!=DUR_16_16_16_16)
	  buf[j++]='s';
	OldInsNote(&mss,buf,GodBits(4),&j);
	OldInsNote(&mss,buf,GodBits(4),&j);
	buf[j++]='e';
	OldInsNote(&mss,buf,GodBits(4),&j);
	duration=DUR_8_8;
	break;
      case DUR_16_16_16_16:
	if (last_duration!=DUR_16_16_16_16)
	  buf[j++]='s';
	k =GodBits(4);
	k2=GodBits(4);
	OldInsNote(&mss,buf,k,&j);
	OldInsNote(&mss,buf,k2,&j);
	OldInsNote(&mss,buf,k,&j);
	OldInsNote(&mss,buf,k2,&j);
	break;
      default:
	if (last_duration!=DUR_4)
	  buf[j++]='q';
	OldInsNote(&mss,buf,GodBits(4),&j);
    }
    last_duration=duration;
  }
  buf[j++]=0;
  return buf;
}

U0 Seed(I64 seed)
{
  I64 i;
  FifoU8Flush(god.fifo);
  for (i=0;i<80;i++)
    GodBitsIns(GOD_GOOD_BITS,(seed*131+i)*0x9E3779B97F4A7C15>>17);
}

U0 TestSongs()
{
  CMakeSongSettings mss;
  I64 seed,cx,bad=0,bad_rev=0,bad_parse=0,cnt=0,n;
  Bool rests,six;
  U8 *a,*b,*r;
  CPlayNote *notes;
  HfPrint("-- Holy songs vs V5.03 GodSongStr\n");
  for (seed=1;seed<=12;seed++)
    for (cx=0;cx<3;cx++)
      for (rests=FALSE;rests<=TRUE;rests++)
	for (six=FALSE;six<=TRUE;six++) {
	  MemSet(&mss,0,sizeof(mss));
	  mss.complexity=cx;
	  mss.rests=rests;
	  mss.six_eight=six;
	  mss.octave=2+seed%5;
	  Seed(seed);
	  a=OldSongStr(&mss);
	  Seed(seed);
	  b=DiabolusSongStr(SONG_MODE_HOLY,FALSE,cx,rests,six,2+seed%5);
	  if (StrCmp(a,b)) {
	    bad++;
	    HfPrint("HOLY DIFF [%s] [%s]\n",a,b);
	  }
	  Free(a);
	  Free(b);
	  cnt++;
//Unholy/Diabolus: Backmask checkbox == PlayStrRev of the plain one.
	  for (n=SONG_MODE_UNHOLY;n<=SONG_MODE_DIABOLUS;n++) {
	    Seed(seed);
	    a=DiabolusSongStr(n,FALSE,cx,rests,six,2+seed%5);
	    music.note_len=1.0;
	    r=PlayStrRev(a);
	    Seed(seed);
	    music.note_len=1.0;
	    b=DiabolusSongStr(n,TRUE,cx,rests,six,2+seed%5);
	    if (StrCmp(r,b)) {
	      bad_rev++;
	      HfPrint("BACKMASK DIFF [%s] [%s] [%s]\n",a,r,b);
	    }
	    if (StrLen(a)>=200 || NewParse(a,&notes)<4)
	      bad_parse++;
	    Free(notes);
	    Free(a);
	    Free(b);
	    Free(r);
	  }
	}
  HfPrint("%d songs\n",cnt);
  Check(!bad,"Holy mode == V5.03 GodSongStr bit for bit");
  Check(!bad_rev,"Backmask checkbox == PlayStrRev");
  Check(!bad_parse,"unholy songs parse and fit the buffer");
  Check(GodBits(8)>=0,"bit fifo still good");
  FifoU8Flush(god.fifo);
}

U0 TestVocab()
{
  I64 i,j,pairs=0,pals=0,bad=0;
  U8 *m;
  HfPrint("-- Vocab table\n");
  for (i=0;i<god.num_words;i++) {
    m=StrMirror(god.words[i]);
    if (StrCmp(m,god.rev_words[i]))
      bad++;
    Free(m);
    j=god.rev_match[i];
    if (j>=0) {
      if (StrCmp(god.rev_words[i],god.words[j]))
	bad++;
      if (j==i)
	pals++;
      else {
	pairs++;
	if (god.rev_match[j]!=i)
	  bad++;
      }
    }
  }
  HfPrint("%d words %d backmasks %d palindromes\n",
	god.num_words,pairs,pals);
  Check(!bad,"rev tables consistent and symmetric");
  Check(pairs==god.num_backmasks && pals==god.num_palindromes,
	"counts match");
  Check(AdversaryWordDolDoc(-1)!=NULL && !AdversaryIsTrueBackmask(-1) &&
	!AdversaryIsTrueBackmask(god.num_words),"bounds");
}

U0 TestBibleEnd()
{
  U8 *st;
  I64 i,lines;
  HfPrint("-- Bible edges\n");
  st=BibleLinesStr(ST_BIBLE_LINES-4,20,TRUE);
  Check(st!=NULL,"lines past the end don't crash");
  lines=StrOcc(st,'\n');
  HfPrint("%d lines at the end: [%s]\n",lines,st);
  Check(1<=lines<=20,"stops at the end of the file");
  Free(st);
  st=BibleLinesStr(300,3,FALSE); //Bible.TXT opens with a Gutenberg header.
  Check(st && StrMatch("In the beginning",st)!=NULL,"line 1 is Genesis");
  Free(st);
  Check(BibleLinesStr(1,0)==NULL,"zero lines");
  for (i=0;i<20;i++)
    AdversaryPassageAt(ST_BIBLE_LINES-(19-i),20);
  Check(TRUE,"AdversaryPassageAt near the end");
  DocClear;
}

U0 TestPsalmody()
{
  I64 psm_octave=4;
  F64 psm_duration=1.0;
  PsmNote *tmpn;
  U8 *s;
  Bool ok=TRUE;
  HfPrint("-- Psalmody edges\n");
  MemSet(&psm,0,sizeof(PsmCtrl));
  psm.head.next=psm.head.last=&psm.head;
  psm.clip.next=psm.clip.last=&psm.clip;
  psm.cur_note=&psm.head;
  psm.incomplete_entry=CAlloc(sizeof(CMenuEntry));

  PsmLoadSongStr("7qB1C7A1D",&psm_octave,&psm_duration);
  PsmInvert;
  tmpn=psm.head.next;
  while (tmpn!=&psm.head) {
    HfPrint("ona %d\n",tmpn->ona);
    if (tmpn->type==PSMT_NOTE && tmpn->ona && !(15<=tmpn->ona<=98))
      ok=FALSE;
    tmpn=tmpn->next;
  }
  s=PsmCvtSong;
  HfPrint("inverted wide song: %s\n",s);
  Free(s);
  Check(ok,"PsmInvert keeps notes in octaves 1-7");
  PsmSongDel(&psm.head);
  psm.cur_note=&psm.head;

  psm_octave=4;
  psm_duration=1.0;
  PsmLoadSongStr("M6/84eCDEFGA",&psm_octave,&psm_duration);
  s=PsmCvtSong;
  HfPrint("meter song: %s\n",s);
  Free(s);
  PsmBackmask;
  s=PsmCvtSong;
  HfPrint("meter song backmasked: %s\n",s);
  Check(!StrNCmp(s,"M6/8",4),"meter stays in front after backmask");
  Free(s);
  PsmBackmask;
  s=PsmCvtSong;
  CheckStr(s,"M6/84eCDEFGA","meter song backmask twice");
  Free(s);
  PsmSongDel(&psm.head);
  psm.cur_note=&psm.head;
}

U0 TestJukeTempo()
{
  F64 tempo=0.0,stac=0.0;
  I64 n=0;
  U8 *song,*words=NULL;
  HfPrint("-- DoomBox int tempo\n");
  FileWrite("B:/TaTempo.HC",
	"//0 has words\nmusic.tempo=3;music.stacatto_factor=0.5;\n"
	"Play(\"4qCDE\",\"one\\0two\\0three\\0\");\n",
	StrLen("//0 has words\nmusic.tempo=3;music.stacatto_factor=0.5;\n"
	"Play(\"4qCDE\",\"one\\0two\\0three\\0\");\n"));
  song=JukeSongStr("B:/TaTempo.HC",&words,&tempo,&stac,&n);
  HfPrint("song [%s] tempo %5.2f stacatto %5.2f n %d\n",song,tempo,stac,n);
  CheckStr(song,"4qCDE","JukeSongStr song");
  Check(n==3 && words && !StrCmp(LstSub(2,words),"three"),"words aligned");
  Check(tempo==3.0,"integer tempo read");
  Check(stac==0.5,"stacatto read");
  Free(song);
  Free(words);
}


U0 TestRunFind()
{
  U8 *st;
  HfPrint("-- F5 Run discovery\n");
  st=DocRunFind("::/Apps/Psalmody/Examples/night.HC","HC.Z");
  if (!st) st=DocRunFind("::/Apps/Psalmody/Examples/night.HC","HC");
  HfPrint("Run for a hymn: %s\n",st);
  Check(st && StrMatch("Psalmody/Run.HC",st),"F5 finds Psalmody/Run.HC");
  Free(st);
  st=DocRunFind("::/Doc/HelpIndex.DD","UC.Z");
  Check(!st,"no Run.UC there");
  Free(st);
}

U0 TestAll()
{
  try {
    TestRunFind;
    TestPlayParser;
    TestSongs;
    TestVocab;
    TestBibleEnd;
    TestPsalmody;
    TestJukeTempo;
  } catch {
    HfPrint("EXCEPTION %c\n",Fs->except_ch);
    ta_fails++;
    Fs->catch_except=TRUE;
  }
}

TestAll;
HfPrint("-- Semordnilap on %d core(s)\n",mp_cnt);
#include "::/Demo/MultiCore/Semordnilap"
Check(sem_num_pairs>=30,"Semordnilap pairs on 1 core");
Check(SemordnilapPair("evil","live") && SemordnilapPair("god","dog"),
	"evil/live god/dog");
SemDel;
HfShot("adv");
HfPrint("TestOracleAdv: %d passed, %d failed\n",ta_passes,ta_fails);
if (ta_fails)
  hf_exit_code=1;
