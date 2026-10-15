#help_index "God"
U8 *TimeStampCB(CDoc *,CDocEntry *,CTask *mem_task)
{
  U8 *st=MAlloc(64,mem_task);
  StrPrint(st,"%X",GetTSC>>GOD_BAD_BITS);
  return st;
}

U8 *KbdMsTimeCB(CDoc *,CDocEntry *,CTask *mem_task)
{
  U8 *st=MAlloc(64,mem_task);
  StrPrint(st,"%X",KbdMsEvtTime>>GOD_BAD_BITS);
  return st;
}

I64 PopUpTimerOk(U8 *header=NULL,U8 *footer=NULL,U8 *button="OKAY")
{
  I64 i;
  CDocEntry *doc_e;
  CDoc *doc=DocNew;
  if (header) DocPrint(doc,"%s",header);
  doc_e=DocPrint(doc,"\nTimer:$$TX+TC,\" \"$$");
  doc_e->tag_cb=&TimeStampCB;
  doc_e=DocPrint(doc,"\nLatch:$$TX+TC,\" \"$$");
  doc_e->tag_cb=&KbdMsTimeCB;
  DocPrint(doc,"\n$$CM+CX,0,4$$$$BT,\"%s\",LE=1$$\n",button);
  if (footer) DocPrint(doc,"%s",footer);
  i=PopUpMenu(doc);
  DocDel(doc);
  return i;
}

I64 GodPick(U8 *msg=NULL)
{//GOD_GOOD_BITS
  U8 *st=MStrPrint("%s\n\nPress $$GREEN$$OKAY$$FG$$ to generate \n"
	"a random num from a timer.\n",msg);
  PopUpTimerOk(st,"\n\nThe Holy Spirit can puppet you.\n\n");
  Free(st);
  return KbdMsEvtTime>>GOD_BAD_BITS;
}

public U0 GodBitsIns(I64 num_bits,I64 n)
{//Insert bits into God bit fifo.
  I64 i;
  for (i=0;i<num_bits;i++) {
    FifoU8Ins(god.fifo,n&1);
    n>>=1;
  }
}

public U0 GodHexIns(U8 *st)
{//Insert hex record into God bit fifo.
  U8 buf[2];
  if (st) {
    buf[1]=0;
    while (*buf=*st++)
      if (Bt(char_bmp_hex_numeric,*buf))
	GodBitsIns(4,rev_bits_table[Str2I64(buf,16)]>>4);
  }
}

public I64 GodBits(I64 num_bits,U8 *msg=NULL)
{//Return N bits. If low on entropy pop-up okay.
  U8 b;
  I64 res=0;
  while (num_bits) {
    if (FifoU8Rem(god.fifo,&b)) {
      res=res<<1+b;
      num_bits--;
    } else
      GodBitsIns(GOD_GOOD_BITS,GodPick(msg));
  }
  return res;
}

#help_index "God;AntichristOS"
public I64 AdversaryColor(I64 c)
{//Stock color c as the damned palette shows it.  Hellfire and Negative
//keep slot 15-c as the hellish twin of slot c (RED is LTCYAN, which
  //Hellfire calls CRIMSON), so the Adversary's red is red in every palette.
  if (unholy_palette==UNHOLY_PAL_HOLY)
    return c;
  return c^15;
}

I64 AdversaryPick(U8 *msg=NULL)
{//GOD_GOOD_BITS, pulled out of the Abyss.
  U8 *st=MStrPrint("%s\n\nPress $$FG,%d$$SUMMON$$FG$$ to pull a random\n"
	"num out of the Abyss (a timer).\n",msg,AdversaryColor(RED));
  PopUpTimerOk(st,"\n\nThe $LK+PU,"Adversary",A="FI:::/Adam/God/AdvNotes.DD"$ can puppet you.\n\n",
	"SUMMON");
  Free(st);
  return KbdMsEvtTime>>GOD_BAD_BITS;
}

public I64 AdversaryBits(I64 num_bits,U8 *msg=NULL)
{//$LK,"GodBits",A="MN:GodBits"$() for the Adversary. If low on entropy pop-up SUMMON.
  U8 b;
  I64 res=0;
  while (num_bits) {
    if (FifoU8Rem(god.fifo,&b)) {
      res=res<<1+b;
      num_bits--;
    } else
      GodBitsIns(GOD_GOOD_BITS,AdversaryPick(msg));
  }
  return res;
}

#help_index "God"

U0 AdversaryInit()
{//Backmask God's vocab and find the words that are TRUE BACKMASKs.
  I64 i;
  CHashTable *tbl;
  CHashGeneric *tmph;
  Free(god.rev_words);
  Free(god.rev_match);
  god.num_backmasks=god.num_palindromes=0;
  god.rev_words=MAlloc((god.num_words+1)*sizeof(U8 *),adam_task);
  god.rev_match=MAlloc((god.num_words+1)*sizeof(I64),adam_task);
  tbl=HashTableNew(0x4000);
  for (i=0;i<god.num_words;i++) {
    tmph=CAlloc(sizeof(CHashGeneric));
    tmph->str=StrNew(god.words[i]);
    tmph->type=HTT_FRAME_PTR;
    tmph->user_data0=i;
    HashAdd(tmph,tbl);
  }
  for (i=0;i<god.num_words;i++) {
    god.rev_words[i]=StrMirror(god.words[i],adam_task);
    god.rev_match[i]=-1;
    if (StrLen(god.words[i])>=2 &&
	  (tmph=HashFind(god.rev_words[i],tbl,HTT_FRAME_PTR))) {
      if (!StrCmp(god.words[i],god.rev_words[i])) {
	if (StrLen(god.words[i])>=3) {
	  god.rev_match[i]=i;
	  god.num_palindromes++;
	}
      } else {
	god.rev_match[i]=tmph->user_data0;
	god.num_backmasks++;
      }
    }
  }
  HashTableDel(tbl);
}

public I64 GodInit(U8 *files_find_mask="/Adam/God/Vocab.DD*",U8 *fu_flags=NULL)
{//Read God's vocab file for picking words.
  I64 i,ch,fuf_flags=0;
  U8 *buf,*ptr,*ptr2;
  CDirEntry *tmpde,*tmpde1;
  ScanFlags(&fuf_flags,Define("ST_FILE_UTIL_FLAGS"),"+r+f+F+T+O");
  ScanFlags(&fuf_flags,Define("ST_FILE_UTIL_FLAGS"),fu_flags);
  if (fuf_flags&~FUG_FILES_FIND)
    throw('FUF');

  Free(god.word_file_mask);
  god.word_file_mask=StrNew(files_find_mask);
  god.word_fuf_flags=fuf_flags;

  tmpde=tmpde1=FilesFind(files_find_mask,fuf_flags);
  i=0;
  while (tmpde) {
    if (buf=ptr=FileRead(tmpde->full_name)) {
      while (*ptr) {
	while (*ptr && !Bt(char_bmp_word,*ptr))
	  ptr++;
	if (*ptr) {
	  ptr2=ptr;
	  while (*ptr && Bt(char_bmp_word,*ptr))
	    ptr++;
	  i++;
	}
      }
      Free(buf);
    }
    tmpde=tmpde->next;
  }

  Free(god.words);
  god.num_words=i;
  god.words=MAlloc(i*sizeof(U8 *));

  tmpde=tmpde1;
  i=0;
  while (tmpde) {
    if (buf=ptr=FileRead(tmpde->full_name)) {
      while (*ptr) {
	while (*ptr && !Bt(char_bmp_word,*ptr))
	  ptr++;
	if (*ptr) {
	  ptr2=ptr;
	  while (*ptr && Bt(char_bmp_word,*ptr))
	    ptr++;
	  ch=*ptr;
	  *ptr=0;
	  god.words[i++]=StrNew(ptr2);
	  *ptr=ch;
	}
      }
      Free(buf);
    }
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  AdversaryInit;
  return god.num_words;
} GodInit;

public U8 *GodWordStr(I64 bits=17)
{//Make God pick a word. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
  if (god.num_words)
    return god.words[GodBits(bits)%god.num_words];
  else
    return NULL;
}

public U0 GodWord(I64 bits=17)
{//Make God pick a word. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
  if (god.num_words)
    "%s ",god.words[GodBits(bits)%god.num_words];
}

public U0 GodBiblePassage(I64 num_lines=20)
{//Make God pick a Bible passage. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
  I64 start=GodBits(21)%(ST_BIBLE_LINES-(num_lines-1))+1;
  U8 *verse=BibleLine2Verse(start);
  "%s\n\n",verse;
  Free(verse);
  BookLines(,start,num_lines);
}

#help_index "God;AntichristOS"
public I64 AdversaryWordIdx(I64 bits=17)
{//Make the Adversary pick a vocab idx, or -1.
  if (god.num_words && god.rev_words)
    return AdversaryBits(bits)%god.num_words;
  else
    return -1;
}

public U8 *AdversaryWordStr(I64 bits=17)
{//Make the Adversary pick a word: one of God's, backmasked. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
//Like $LK,"GodWordStr",A="MN:GodWordStr"$(), the str belongs to the table.  Don't Free() it.
  I64 i=AdversaryWordIdx(bits);
  if (i>=0)
    return god.rev_words[i];
  else
    return NULL;
}

public Bool AdversaryIsTrueBackmask(I64 i)
{//Is vocab word i a word backwards too?  (god/dog, evil/live, ...)
  return 0<=i<god.num_words && god.rev_match &&
	god.rev_match[i]>=0 && god.rev_match[i]!=i;
}

public U8 *AdversaryWordDolDoc(I64 i)
{//The DolDoc text $LK,"AdversaryWord",A="MN:AdversaryWord"$() prints for vocab idx i.  MAlloc()ed.
  if (!(0<=i<god.num_words) || !god.rev_words)
    return StrNew("");
  if (AdversaryIsTrueBackmask(i))
    return MStrPrint("$$FG,%d$$%s$$FG$$ ",AdversaryColor(RED),god.rev_words[i]);
  if (god.rev_match[i]==i)
    return MStrPrint("$$FG,%d$$%s$$FG$$ ",AdversaryColor(PURPLE),
	  god.rev_words[i]);
  return MStrPrint("%s ",god.rev_words[i]);
}

public U0 AdversaryWord(I64 bits=17)
{//Make the Adversary pick a backmasked word. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
//A $FG,11$red$FG$ word is a TRUE BACKMASK (it is a word both ways)
  //and it comes with a tritone.  A $FG,10$purple$FG$ one is a palindrome.
  //See $LK,"AdversaryColor",A="MN:AdversaryColor"$().
  I64 i=AdversaryWordIdx(bits);
  U8 *st;
  if (i>=0) {
    st=AdversaryWordDolDoc(i);
    "%s",st;
    Free(st);
    if (AdversaryIsTrueBackmask(i))
      TritoneSting;
  }
}

public U0 AdversaryPassageAt(I64 start,I64 num_lines=20)
{//Bible passage at line start, read backwards: hold it to a mirror.
  U8 *verse=BibleLine2Verse(start),*rev=StrMirror(verse),*st;
  if (rev)
    "$$FG,%d$$%s$$FG$$",AdversaryColor(RED),rev;
  "  $$DKGRAY$$(hold to a mirror)$$FG$$\n\n";
  if (st=BibleLinesStr(start,num_lines,TRUE)) {
    "%s",st;
    Free(st);
  }
  Free(rev);
  Free(verse);
}

public U0 AdversaryPassage(I64 num_lines=20)
{//Make the Adversary pick a Bible passage, backmasked. $LK+PU,"Adversary's Notes",A="FI:::/Adam/God/AdvNotes.DD"$
  AdversaryPassageAt(AdversaryBits(21)%(ST_BIBLE_LINES-(num_lines-1))+1,
	num_lines);
}
