CTask *JukeReward(U8 *msg)
{
  U8 *buf;
  CDoc *doc;
  CTask *res=Spawn(&SrvCmdLine,NULL,"Curse",,Fs);
  StrCpy(res->task_title,"Curse");
  res->title_src=TTS_LOCKED_CONST;

  doc=DocNew(,res);
  DocPrint(doc,"$$WW+H,1$$$$RED$$%s",msg);

  buf=MStrPrint("DocEd(0x%X);",doc);
  TaskExe(res,NULL,buf,1<<JOBf_EXIT_ON_COMPLETE|1<<JOBf_FREE_ON_COMPLETE);
  Free(buf);
  TaskWait(res);

  res->border_src =BDS_CONST;
  res->border_attr=LTGRAY<<4+DrvTextAttrGet(':')&15;
  res->text_attr  =LTGRAY<<4+BLUE;
  res->win_inhibit=WIG_NO_FOCUS_TASK_DFT;
  WinHorz(Fs->win_right+2,TEXT_COLS-2,res);
  WinVert(2,TEXT_ROWS-2,res);

  WinFocus(Fs->parent_task);
  return res;
}

CTask *SingleSong(U8 *msg,U8 *name)
{
  CTask *task=Spawn(&SrvCmdLine,NULL,name,,Fs);
  StrCpy(task->task_title,name);
  task->title_src=TTS_LOCKED_CONST;
  TaskExe(task,Fs,";",1<<JOBf_WAKE_MASTER|1<<JOBf_FREE_ON_COMPLETE);
  WinHorz(task->win_left,task->win_left+50,task);
  WinVert(2,2+8,task);
  task->win_inhibit=WIG_NO_FOCUS_TASK_DFT;
  TaskExe(task,NULL,msg,1<<JOBf_EXIT_ON_COMPLETE|1<<JOBf_FREE_ON_COMPLETE);
  DocPut(task)->max_entries=100;
  return task;
}

#define JB_RUN_LEVEL_NULL	0
#define JB_RUN_LEVEL_ONE	1
#define JB_RUN_LEVEL_TWO	2

//AntichristOS DoomBox: <b> plays a hymn backmasked.
CTask *jb_backmask_task=NULL;
I64 jb_backmask_notes=0,jb_backmask_loops=0;

U8 *JBWordsCat(U8 *words,I64 *_len,U8 *word)
{//Append one entry to a \0-separated lst with an explicit length.
  I64 l=StrLen(word)+1;
  U8 *res=MAlloc(*_len+l+1);
  if (words)
    MemCpy(res,words,*_len);
  StrCpy(res+*_len,word);
  *_len+=l;
  res[*_len]=0;
  Free(words);
  return res;
}

U0 JBLexNum(CCmpCtrl *cc,F64 *_num)
{//music.tempo=2.5; or music.tempo=3;
  switch (Lex(cc)) {
    case TK_F64: *_num=cc->cur_f64; break;
    case TK_I64: *_num=cc->cur_i64; break;
  }
}

public U8 *JukeSongStr(U8 *filename,U8 **_words=NULL,
	F64 *_tempo=NULL,F64 *_stacatto=NULL,I64 *_notes=NULL)
{//All $LK,"Play",A="MN:Play"$() strs of a song file joined, without running it.
//Words come back aligned one per note.  Free() the results.
  CCmpCtrl *cc=CmpCtrlNew(MStrPrint("#include \"%s\"",filename));
  U8 *song=StrNew(""),*st,*st2,*w,*words=NULL,*word;
  I64 i,n,total=0,words_len=0,octave,top,bottom;
  F64 note_len;
  CPlayNote *notes;
  while (Lex(cc)) {
    if (cc->token==TK_IDENT) {
      if (!StrCmp(cc->cur_str,"Play")) {
	if (Lex(cc)=='(' && Lex(cc)==TK_STR) {
	  st=LexExtStr(cc);
	  octave=4; note_len=1.0; top=4; bottom=4;
	  n=PlayNotesNew(st,&notes,music.note_map,&octave,&note_len,
		&top,&bottom);
	  Free(notes);
	  st2=MStrPrint("%s%s",song,st);
	  Free(song);
	  song=st2;
	  w=NULL;
	  if (cc->token==',' && Lex(cc)==TK_STR)
	    w=LexExtStr(cc);
	  for (i=0;i<n;i++) {
	    if (!w || !(word=LstSub(i,w)))
	      word=" ";
	    words=JBWordsCat(words,&words_len,word);
	  }
	  total+=n;
	  Free(w);
	  Free(st);
	}
      } else if (!StrCmp(cc->cur_str,"music") &&
	    Lex(cc)=='.' && Lex(cc)==TK_IDENT) {
	if (!StrCmp(cc->cur_str,"tempo")) {
	  if (Lex(cc)=='=' && _tempo)
	    JBLexNum(cc,_tempo);
	} else if (!StrCmp(cc->cur_str,"stacatto_factor")) {
	  if (Lex(cc)=='=' && _stacatto)
	    JBLexNum(cc,_stacatto);
	}
      }
    }
  }
  CmpCtrlDel(cc);
  if (_words)
    *_words=words;
  else
    Free(words);
  if (_notes)
    *_notes=total;
  return song;
}

public U0 JukeBackmask(U8 *filename)
{//Play a whole hymn backwards, words and all.  Graphics are lost.
  U8 *song=NULL,*words=NULL,*rev_name;
  F64 tempo=2.5,stacatto=0.9;
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  try {
    song=JukeSongStr(filename,&words,&tempo,&stacatto,&jb_backmask_notes);
    jb_backmask_loops=0;
    music.tempo=tempo;
    music.stacatto_factor=stacatto;
    rev_name=StrMirror(filename);
    "$$WW,1$$$$RED$$%s$$FG$$\n%d notes, backmasked.\n\n",
	  rev_name,jb_backmask_notes;
    Free(rev_name);
    while (jb_backmask_notes && !ScanKey) {
      music.octave=4;
      music.note_len=1.0;
      PlayRev(song,words);
      jb_backmask_loops++;
    }
  } catch
    PutExcept;
  Free(song);
  Free(words);
  Snd;
}

U0 JukeBackmaskStop()
{
  if (jb_backmask_task && TaskValidate(jb_backmask_task))
    Kill(jb_backmask_task);
  jb_backmask_task=NULL;
}

Bool JBPutKey(CDoc *doc,U8 *,I64 ch,I64 sc)
{//ch=ASCII; sc=scan_code
  CDocEntry *doc_ce=doc->cur_entry,*doc_e;
  CDirEntry *tmpde;
  I64 i;
  U8 *st,*st2;
  CDoc *doc2;
  if (!(sc&(SCF_ALT|SCF_CTRL|SCF_SHIFT))
	&& doc_ce->type_u8==DOCT_MENU_VAL && doc_ce->left_exp>=0) {
    tmpde=doc_ce->left_exp;
    if (sc.u8[0]==SC_DELETE ) {
      Beep;
      Silent;
      Del(tmpde->full_name);
      Silent(OFF);
    } else if ('0'<=ch<='9') {
      if (StrLen(doc_ce->tag)>1)
	doc_ce->tag[0]=ch;
      doc2=DocRead(tmpde->full_name);
      DocGoToLine(doc2,1);
      doc_e=doc2->cur_entry;
      if (doc_e!=doc2 && doc_e->type_u8==DOCT_TEXT && StrLen(doc_e->tag)>=3) {
	doc_e->tag[2]=ch;
	DocWrite(doc2);
      }
      DocDel(doc2);
      return TRUE;
    } else if (ch=='r') {
      if (!DocTreeFFind(tmpde->full_name,"Reward1")) {
	doc2=DocRead(tmpde->full_name);
	DocGoToLine(doc2,2);
	DocPrint(doc2,
	      "\n$$TR,\"Reward1\"$$\n"
	      "$$ID,2$$CallExtStr(\"JukeReward\",\"\"\n"
	      "$$TR,\"Reward2\"$$\n"
	      "$$ID,2$$\n"
	      "$$ID,-2$$\n"
	      ");\n$$ID,-2$$\n"
	      );
	DocWrite(doc2);
	DocDel(doc2);
      }
      if (DocTreeFFind(tmpde->full_name,"Reward1/Reward2")) {
	for (i=0;i<5;i++) {
	  st=MStrPrint("%s %s %s %s ",AdversaryWordStr,
		AdversaryWordStr,AdversaryWordStr,AdversaryWordStr);
	  DocTreeFAppend(tmpde->full_name,"Reward1/Reward2",
		"\"%s\"\n",st);
	  Free(st);
	}
	In("");
      }
      return TRUE;
    } else if (ch=='b') {
      JukeBackmaskStop;
      st=StrNew(tmpde->name);
      FileExtRem(st);
      st2=StrMirror(st);
      Free(st);
      st=MStrPrint("JukeBackmask(\"%Q\");",tmpde->full_name);
      MusicSettingsRst;
      jb_backmask_task=SingleSong(st,st2);
      Free(st);
      Free(st2);
      return TRUE;
    } else if (ch==CH_SPACE||ch==CH_ESC)
      tmpde->user_data++; //JB_RUN_LEVEL++
//<SPACE> is followed by <ESC> --> JB_RUN_LEVEL_TWO
      //Actual <ESC> just exits--> JB_RUN_LEVEL_ONE
  }
  return FALSE;
}

public U0 JukeBox(U8 *dirname="~/Psalmody",U8 **_filename=NULL)
{//_filename is for using this as a song-chooser program.
  I64 i=0,rating;
  U8 *st,*st2;
  CDirEntry *tmpde,*tmpde1;
  CDoc *doc=DocNew,*s;
  CDocEntry *doc_e;
  CTask *task=NULL;
  if (_filename)
    *_filename=NULL;
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  AutoComplete;
  try {
    dirname=StrNew(dirname);
    st=MStrPrint("%s/*.HC*",dirname);
    tmpde=tmpde1=FilesFind(st);
    Free(st);
    Free(dirname);
    doc->user_put_key=&JBPutKey;
    DocPrint(doc,
	  "$$RED$$DoomBox$$FG$$: every hymn hides a message.  "
	  "Play it backwards.\n\n"
	  "Key: $$GREEN$$Graphics $$BLUE$$Words $$RED$$No Nothing "
	  "$$BLACK$$Incomplete $$CYAN$$Special$$FG$$\n\n"
	  "$$GREEN$$<DEL>$$FG$$\tto delete a song.\n"
	  "'$$GREEN$$0$$FG$$'-'$$GREEN$$9$$FG$$'\tto rate a song.\n"
	  "'$$GREEN$$r$$FG$$'\tto get your curse from the Adversary.\n"
	  "'$$GREEN$$b$$FG$$'\tto play a song backmasked "
	  "(words, no graphics).\n");
    while (tmpde) {
      if (!(i++%5))
	DocPrint(doc,"\n");
      if (FileOcc("Play(",tmpde->full_name,"")) {
	st=StrNew(tmpde->name);
	FileExtRem(st);
	s=DocRead(tmpde->full_name);
	doc_e=s->head.next;
	while (doc_e!=s && doc_e->type_u8!=DOCT_TEXT)
	  doc_e=doc_e->next;
	rating='0';
	if (doc_e!=s && doc_e->type_u8==DOCT_TEXT) {
	  if ('0'<=doc_e->tag[2]<='9')
	    rating=doc_e->tag[2];
	  if (StrMatch("incomplete",doc_e->tag))
	    DocPrint(doc,"$$BLACK$$");
	  else if (StrMatch("has graphics",doc_e->tag))
	    DocPrint(doc,"$$GREEN$$");
	  else if (StrMatch("has words",doc_e->tag))
	    DocPrint(doc,"$$BLUE$$");
	  else if (StrMatch("special",doc_e->tag))
	    DocPrint(doc,"$$CYAN$$");
	  else if (StrMatch("no nothing",doc_e->tag)) {
	    DocPrint(doc,"$$RED$$");
	    if (FileOcc("\\0",tmpde->full_name,"")) {
	      s->cur_entry=doc_e->next;
	      s->cur_col=0;
	      DocEntryDel(s,doc_e);
	      DocPrint(s,"//0 has words\n");
	      DocWrite(s);
	    }
	  }
	  DocPrint(doc,"$$MU-UL,\"%c%-8ts\",LE=%d$$ ",rating,st,tmpde);
	  tmpde->user_data=JB_RUN_LEVEL_NULL;
	}
	DocDel(s);
	Free(st);
      }
      tmpde=tmpde->next;
    }
    DocPrint(doc,"\n$$CYAN$$$$MU-UL,\"DONE\",LE=%d$$\n",DOCM_CANCEL);
    while (TRUE) {
      if (_filename)
	tmpde=PopUpMenu(doc,DOF_INTERCEPT_TASK_END);
      else
	tmpde=PopUpMenu(doc);
      if (task)
	Kill(task);
      JukeBackmaskStop;
      if (tmpde<=0) break;
      st2=StrNew(tmpde->name);
      if (_filename) {
	Free(*_filename);
	*_filename=StrNew(tmpde->full_name);
      }
      if (tmpde->user_data==JB_RUN_LEVEL_ONE) break; //<ESC>
      tmpde->user_data=JB_RUN_LEVEL_NULL; //Rst from <SPACE>
      FileExtRem(st2);
      st=MStrPrint("ExeFile(\"%s\");",tmpde->full_name);
      MusicSettingsRst;
      task=SingleSong(st,st2);
      Free(st2);
      Free(st);
    }
    DocDel(doc);
    DirTreeDel(tmpde1);
  } catch
    PutExcept;
  JukeBackmaskStop;
  SettingsPop;
}

public U0 DoomBox(U8 *dirname="~/Psalmody",U8 **_filename=NULL)
{//$LK,"JukeBox",A="FF:::/Apps/Psalmody/JukeBox.HC,JukeBox"$() by its AntichristOS name.  <b> backmasks.
  JukeBox(dirname,_filename);
}
