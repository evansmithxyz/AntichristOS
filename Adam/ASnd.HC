#help_index "Snd"
public U0 SndTaskEndCB()
{//Will turn-off snd when a task gets killed.
  Snd;
  Exit;
}

#help_index "Snd/Math;Math"
public F64 Saw(F64 t,F64 period)
{//Sawtooth. 0.0 - 1.0 think "(Sin+1)/2"
  if (period) {
    if (t>=0.0)
      return t%period/period;
    else
      return 1.0+t%period/period;
  } else
    return 0.0;
}

public F64 FullSaw(F64 t,F64 period)
{//Plus&Minus Sawtooth. 1.0 - -1.0 think "Sin"
  if (period) {
    if (t>=0.0)
      return 2.0*(t%period/period)-1.0;
    else
      return 2.0*(t%period/period)+1.0;
  } else
    return 0.0;
}

public F64 Caw(F64 t,F64 period)
{//Cawtooth. 1.0 - 0.0 think "(Cos+1)/2"
  if (period) {
    if (t>=0.0)
      return 1.0-t%period/period;
    else
      return -(t%period)/period;
  } else
    return 1.0;
}

public F64 FullCaw(F64 t,F64 period)
{//Plus&Minus Cawtooth. 1.0 - -1.0 think "Cos"
  if (period) {
    if (t>=0.0)
      return -2.0*(t%period/period)+1.0;
    else
      return -2.0*(t%period/period)-1.0;
  } else
    return 1.0;
}

public F64 Tri(F64 t,F64 period)
{//Triangle waveform. 0.0 - 1.0 - 0.0
  if (period) {
    t=2.0*(Abs(t)%period)/period;
    if (t<=1.0)
      return t;
    else
      return 2.0-t;
  } else
    return 0.0;
}

public F64 FullTri(F64 t,F64 period)
{//Plus&Minus Triangle waveform. 0.0 - 1.0 - 0.0 - -1.0 -0.0
  if (period) {
    t=4.0*(t%period)/period;
    if (t<=-1.0) {
      if (t<=-3.0)
	return t+4.0;
      else
	return -2.0-t;
    } else {
      if (t<=1.0)
	return t;
      else if (t<=3.0)
	return 2.0-t;
      else
	return t-4.0;
    }
  } else
    return 0.0;
}

#help_index "Snd/Music"

public class CMusicGlbls
{
  U8	*cur_song;
  CTask	*cur_song_task;
  I64	octave;
  F64	note_len;
  U8	note_map[7];
  Bool	mute;
  I64	meter_top,meter_bottom;
  F64	tempo,stacatto_factor;

  //If you wish to sync with a
  //note in a Play() string.  0 is the start
  I64	play_note_num;

  F64	tM_correction,last_Beat,last_tM;

  //AntichristOS: <CTRL-ALT-r> backmasks every song,
  //<CTRL-ALT-SHIFT-r> plays them in the Unholy (Locrian) mode.
  Bool	backmask,unholy;
} music={NULL,NULL,4,1.0,{0,2,3,5,7,8,10},FALSE,4,4,2.5,0.9,0,0,0,0,
	FALSE,FALSE};

#help_index "Snd/Music;Time/Seconds"
public F64 tM()
{//Time in seconds synced to music subsystem.
  return (cnts.jiffies+music.tM_correction)/JIFFY_FREQ;
}

public F64 Beat()
{//Time in music beats.
  F64 res,cur_tM;
  PUSHFD
  CLI
  if (mp_cnt>1)
    while (LBts(&sys_semas[SEMA_TMBEAT],0))
      PAUSE
  cur_tM=tM;
  res=music.last_Beat;
  if (music.tempo)
    res+=(cur_tM-music.last_tM)*music.tempo;
  music.last_tM=cur_tM;
  music.last_Beat=res;
  LBtr(&sys_semas[SEMA_TMBEAT],0);
  POPFD
  return res;
}

#help_index "Snd/Music"
U8 *MusicSetOctave(U8 *st)
{
  I64 ch;
  ch=*st++;
  while ('0'<=ch<='9') {
    music.octave=ch-'0';
    ch=*st++;
  }
  return --st;
}

U8 *MusicSetMeter(U8 *st)
{
  I64 ch;
  ch=*st++;
  while (ch=='M') {
    ch=*st++;
    if ('0'<=ch<='9') {
      music.meter_top=ch-'0';
      ch=*st++;
    }
    if (ch=='/')
      ch=*st++;
    if ('0'<=ch<='9') {
      music.meter_bottom=ch-'0';
      ch=*st++;
    }
  }
  return --st;
}

U8 *MusicSetNoteLen(U8 *st)
{
  Bool cont=TRUE;
  do {
    switch (*st++) {
      case 'w': music.note_len=4.0;  break;
      case 'h': music.note_len=2.0;  break;
      case 'q': music.note_len=1.0;  break;
      case 'e': music.note_len=0.5;   break;
      case 's': music.note_len=0.25;   break;
      case 't': music.note_len=2.0*music.note_len/3.0; break;
      case '.': music.note_len=1.5*music.note_len; break;
      default:
	st--;
	cont=FALSE;
    }
  } while (cont);
  return st;
}

public I8 Note2Ona(I64 note,I64 octave=4)
{//Note to ona. Mid C is ona=51, note=3 and octave=4.
  if (note<3)
    return (octave+1)*12+note;
  else
    return octave*12+note;
}

public I8 Ona2Note(I8 ona)
{//Ona to note in octave. Mid C is ona=51, note=3 and octave=4.
  return ona%12;
}

public I8 Ona2Octave(I8 ona)
{//Ona to octave. Mid C is ona=51, note=3 and octave=4.
  I64 note=ona%12,octave=ona/12;
  if (note<3)
    return octave-1;
  else
    return octave;
}

#help_index "Snd/Music;AntichristOS"
U8 music_unholy_note_map[7]={11,1,3,4,6,8,9};
//The Unholy (Locrian) note map used by $LK,"Play",A="MN:Play"$() when
//music.unholy is set: A->Ab B->Bb C D->Db E->Eb F G->Gb, which is
//C Locrian, the mode with a tritone over its root.  music.note_map is
//never touched (Psalmody spells notes with it when it saves).

U8 *music_note_lst="A\0A#\0B\0C\0C#\0D\0D#\0E\0F\0F#\0G\0G#\0";

public U8 *MusicNoteMapCur()
{//The note map Play() uses now: Holy or Unholy.
  if (music.unholy)
    return music_unholy_note_map;
  else
    return music.note_map;
}

public U8 *StrMirror(U8 *src,CTask *mem_task=NULL)
{//Backmask a str: returns a reversed copy, MAlloc()ed.
  I64 i,n;
  U8 *res;
  if (!src) return NULL;
  n=StrLen(src);
  res=MAlloc(n+1,mem_task);
  for (i=0;i<n;i++)
    res[i]=src[n-1-i];
  res[n]=0;
  return res;
}

class CPlayNote
{
  I64	ona;
  F64	note_len;
  Bool	tie;
};

U8 *PlayTokNoteLen(U8 *st,F64 *_note_len)
{
  Bool cont=TRUE;
  do {
    switch (*st++) {
      case 'w': *_note_len=4.0;  break;
      case 'h': *_note_len=2.0;  break;
      case 'q': *_note_len=1.0;  break;
      case 'e': *_note_len=0.5;  break;
      case 's': *_note_len=0.25; break;
      case 't': *_note_len=2.0* *_note_len/3.0; break;
      case '.': *_note_len=1.5* *_note_len; break;
      default:
	st--;
	cont=FALSE;
    }
  } while (cont);
  return st;
}

U8 *PlayTokNote(U8 *st,U8 *note_map,I64 *_octave,F64 *_note_len,
	I64 *_meter_top,I64 *_meter_bottom,I64 *_ona,Bool *_tie)
{//Parse one note of a $LK,"Play",A="MN:Play"$() str.  NULL at the end.
  I64 note,octave;
  U8 *last_st;
  *_tie=FALSE;
  do {
    last_st=st;
    if (*st=='(') {
      *_tie=TRUE;
      st++;
    } else {
      while (*st=='M') {
	st++;
	if ('0'<=*st<='9')
	  *_meter_top=*st++ -'0';
	if (*st=='/')
	  st++;
	if ('0'<=*st<='9')
	  *_meter_bottom=*st++ -'0';
      }
      while ('0'<=*st<='9')
	*_octave=*st++ -'0';
      st=PlayTokNoteLen(st,_note_len);
    }
  } while (st!=last_st);
  if (!*st) return NULL;
  note=*st++ -'A';
  if (0<=note<7) {
    note=note_map[note];
    octave=*_octave;
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
    *_ona=Note2Ona(note,octave);
  } else
    *_ona=0;
  return st;
}

I64 PlayNotesNew(U8 *st,CPlayNote **_notes,U8 *note_map,I64 *_octave,
	F64 *_note_len,I64 *_meter_top,I64 *_meter_bottom)
{//Parse a whole Play() str into a MAlloc()ed note array.  Updates state.
  I64 n=0,octave=*_octave,top=*_meter_top,bottom=*_meter_bottom,ona;
  F64 note_len=*_note_len;
  Bool tie;
  U8 *ptr=st;
  CPlayNote *res;
  while (ptr=PlayTokNote(ptr,note_map,&octave,&note_len,&top,&bottom,
	&ona,&tie))
    n++;
  res=MAlloc((n+1)*sizeof(CPlayNote));
  n=0;
  while (st=PlayTokNote(st,note_map,_octave,_note_len,_meter_top,
	_meter_bottom,&ona,&tie)) {
    res[n].ona=ona;
    res[n].note_len=*_note_len;
    res[n].tie=tie;
    n++;
  }
  *_notes=res;
  return n;
}

U8 *PlayLenTok(U8 *dst,F64 note_len)
{//Write the duration token that gives note_len (or the nearest one).
  U8 *bases="whqes",*mods="  t . tttt...";
  F64 d,base=4.0,best_d=F64_MAX;
  I64 i,j,k,best_i=2,best_j=0;
  for (i=0;i<5;i++) {
    for (j=0;j<6;j++) {
      d=base;
      for (k=0;k<2;k++)
	if (mods[2*j+k]=='t')
	  d=2.0*d/3.0;
	else if (mods[2*j+k]=='.')
	  d=1.5*d;
      d=Abs(d-note_len);
      if (d<best_d-0.000001) {
	best_d=d;
	best_i=i;
	best_j=j;
      }
    }
    base*=0.5;
  }
  *dst++=bases[best_i];
  for (k=0;k<2;k++)
    if (mods[2*best_j+k]!=CH_SPACE)
      *dst++=mods[2*best_j+k];
  return dst;
}

public U8 *PlayStrRev(U8 *st,CTask *mem_task=NULL)
{//Backmask a $LK,"Play",A="MN:Play"$() str: same notes, reverse order.
//Starts from the current octave and duration, puts an explicit
  //octave and duration on the first note, moves ties so they still
  //join the same pair of notes.  Returns a MAlloc()ed str.
  I64 i,n,o,last_octave=-1,octave=music.octave,
	top=music.meter_top,bottom=music.meter_bottom;
  F64 note_len=music.note_len,last_len=-1.0;
  CPlayNote *notes;
  U8 *res,*dst,*src;
  if (!st) return NULL;
  n=PlayNotesNew(st,&notes,music.note_map,&octave,&note_len,&top,&bottom);
  res=dst=MAlloc(8*n+16,mem_task);
  if (StrOcc(st,'M')) {
    *dst++='M';
    *dst++='0'+top;
    *dst++='/';
    *dst++='0'+bottom;
  }
  for (i=n-1;i>=0;i--) {
    if (i>0 && notes[i-1].tie)
      *dst++='(';
    if (notes[i].ona) {
      o=Ona2Octave(notes[i].ona);
      if (o!=last_octave && 0<=o<=9) {
	*dst++='0'+o;
	last_octave=o;
      }
    }
    if (Abs(notes[i].note_len-last_len)>0.000001) {
      dst=PlayLenTok(dst,notes[i].note_len);
      last_len=notes[i].note_len;
    }
    if (notes[i].ona) {
      src=LstSub(Ona2Note(notes[i].ona),music_note_lst);
      while (*src)
	*dst++=*src++;
    } else
      *dst++='R';
  }
  *dst=0;
  Free(notes);
  return res;
}

U0 MusicNotePlay(I64 ona,F64 note_len,Bool tie,I64 timeout_val)
{
  I64 timeout_val2;
  F64 d,on_jiffies,off_jiffies;
  d=JIFFY_FREQ*note_len/music.tempo;
  on_jiffies	=d*music.stacatto_factor;
  off_jiffies =d*(1.0-music.stacatto_factor);

  timeout_val+=on_jiffies;
  timeout_val2=timeout_val+off_jiffies;

  if (!music.mute)
    Snd(ona);
  SleepUntil(timeout_val);
  music.tM_correction+=on_jiffies-ToI64(on_jiffies);

  if (!music.mute && !tie)
    Snd;
  SleepUntil(timeout_val2);
  music.tM_correction+=off_jiffies-ToI64(off_jiffies);
}

public U0 PlayRev(U8 *st,U8 *words=NULL)
{//Play a song backwards (backmasked).  Words come out in reverse order
//and each word is reversed unless it holds DolDoc commands.
  CPlayNote *notes;
  I64 i,n,timeout_val;
  U8 *word,*w2;
  music.play_note_num=0;
  if (!st) return;
  n=PlayNotesNew(st,&notes,MusicNoteMapCur,&music.octave,&music.note_len,
	&music.meter_top,&music.meter_bottom);
  for (i=n-1;i>=0;i--) {
    timeout_val=cnts.jiffies;
    if (words && (word=LstSub(i,words)) && StrCmp(word," ")) {
      if (StrOcc(word,'$$'))
	"%s",word;
      else {
	w2=StrMirror(word);
	"%s",w2;
	Free(w2);
      }
    }
    MusicNotePlay(notes[i].ona,notes[i].note_len,i>0 && notes[i-1].tie,
	  timeout_val);
    music.play_note_num++;
  }
  Free(notes);
}

#help_index "Snd/Music"
public U0 Play(U8 *st,U8 *words=NULL)
{/* Notes are entered with a capital letter.

Octaves are entered with a digit and
stay set until changed.  Mid C is octave 4.

Durations are entered with
'w' whole note
'h' half note
'q' quarter note
'e' eighth note
't' sets to 2/3rds the current duration
'.' sets to 1.5 times the current duration
durations stay set until changed.

'(' tie, placed before the note to be extended

$LK,"music.meter_top",A="MN:CMusicGlbls"$,$LK,"music.meter_bottom",A="MN:CMusicGlbls"$ is set with
"M3/4"
"M4/4"
etc.

Sharp and flat are done with '#' or 'b'.

The var music.stacatto_factor can
be set to a range from 0.0 to 1.0.

The var music.tempo is quarter-notes
per second.It defaults to
2.5 and gets faster when bigger.

AntichristOS: if music.backmask is set
the whole str is played backwards (see
PlayRev() and PlayStrRev()) and if
music.unholy is set the letters are
mapped to the Unholy (Locrian) mode.
*/
  U8 *word,*note_map;
  I64 i=0,ona,timeout_val;
  Bool tie;
  if (music.backmask) {
    PlayRev(st,words);
    return;
  }
  note_map=MusicNoteMapCur;
  music.play_note_num=0;
  while (TRUE) {
    timeout_val=cnts.jiffies;
    if (!(st=PlayTokNote(st,note_map,&music.octave,&music.note_len,
	  &music.meter_top,&music.meter_bottom,&ona,&tie)))
      break;
    if (words && (word=LstSub(i++,words)) && StrCmp(word,""))
      "%s",word;
    MusicNotePlay(ona,music.note_len,tie,timeout_val);
    music.play_note_num++;
  }
}

U0 MusicSettingsRst()
{
  music.play_note_num=0;
  music.stacatto_factor=0.9;
  music.tempo=2.5;
  music.octave=4;
  music.note_len=1.0;
  music.meter_top=4;
  music.meter_bottom=4;
  SndRst;
  PUSHFD
  CLI
  if (mp_cnt>1)
    while (LBts(&sys_semas[SEMA_TMBEAT],0))
      PAUSE
  music.last_tM=tM;
  music.last_Beat=0.0;
  LBtr(&sys_semas[SEMA_TMBEAT],0);
  POPFD
}

MusicSettingsRst;

U0 CurSongTask()
{
  Fs->task_end_cb=&SndTaskEndCB;
  while (TRUE)
    Play(music.cur_song);
}

#help_index "Snd/Music;AntichristOS"
U0 TritoneTask(I64 data)
{
  I64 ona=data&0xFF;
  Fs->task_end_cb=&SndTaskEndCB;
  if (!music.mute) {
    if (data&0x100) {
      Snd(ona);
      Sleep(150);
      Snd(ona+6);
    } else {
      Snd(ona+6);
      Sleep(150);
      Snd(ona);
    }
    Sleep(300);
  }
  Snd;
}

public CTask *TritoneSting(I64 ona=57,Bool rising=TRUE)
{//Diabolus in musica: ona and the note a tritone above, in the background.
  if (rising)
    ona|=0x100;
  return Spawn(&TritoneTask,ona,"Diabolus",,Fs);
}

U0 CtrlAltR(I64 sc)
{//Runs in the WinMgr: only flip flags and spawn, never Sleep.
  if (sc&SCF_SHIFT) {
    music.unholy=!music.unholy;
    TritoneSting(45,music.unholy);
  } else {
    music.backmask=!music.backmask;
    TritoneSting(57,music.backmask);
  }
}
CtrlAltCBSet('R',&CtrlAltR,"Cmd /Backmask All Music",
	"Cmd /Unholy Mode (Locrian)");

#help_index "Snd"

#define SE_NOISE	0
#define SE_SWEEP	1

class CSoundEffectFrame
{
  I32	type;
  I8	ona1,ona2;
  F64	duration;
};

U0 SoundEffectEndTaskCB()
{
  Free(FramePtr("CSoundEffectFrame"));
  music.mute--;
  SndTaskEndCB;
}

U0 SoundEffectTask(CSoundEffectFrame *ns)
{
  I64 i,ona;
  F64 t0=tS,t,timeout=t0+ns->duration;
  FramePtrAdd("CSoundEffectFrame",ns);
  Fs->task_end_cb=&SoundEffectEndTaskCB;
  switch (ns->type) {
    case SE_NOISE:
      i=MaxI64(ns->ona2-ns->ona1,1);
      while (tS<timeout) {
	ona=RandU16%i+ns->ona1;
	Snd(ona);
	t=Clamp(3000.0/Ona2Freq(ona),1.0,50.0);
	if (t+tS>timeout)
	  t=timeout-tS;
	Sleep(t);
      }
      break;
    case SE_SWEEP:
      while (tS<timeout) {
	t=(tS-t0)/ns->duration;
	ona=(1.0-t)*ns->ona1+t*ns->ona2;
	Snd(ona);
	t=Clamp(3000.0/Ona2Freq(ona),1.0,50.0);
	if (t+tS>timeout)
	  t=timeout-tS;
	Sleep(t);
      }
      break;
  }
}

public CTask *Noise(I64 mS,F64 min_ona,F64 max_ona)
{//Make white noise for given number of mS.
  CSoundEffectFrame *ns;
  if (mS>0) {
    ns=MAlloc(sizeof(CSoundEffectFrame));
    ns->type=SE_NOISE;
    ns->duration=mS/1000.0;
    ns->ona1=min_ona;
    ns->ona2=max_ona;
    music.mute++;
    return Spawn(&SoundEffectTask,ns,"Noise",,Fs);
  } else
    return NULL;
}

public CTask *Sweep(I64 mS,F64 ona1,F64 ona2)
{//Sweep through freq range in given number of mS.
  CSoundEffectFrame *ns;
  if (mS>0) {
    ns=MAlloc(sizeof(CSoundEffectFrame));
    ns->type=SE_SWEEP;
    ns->duration=mS/1000.0;
    ns->ona1=ona1;
    ns->ona2=ona2;
    music.mute++;
    return Spawn(&SoundEffectTask,ns,"Noise",,Fs);
  } else
    return NULL;
}
