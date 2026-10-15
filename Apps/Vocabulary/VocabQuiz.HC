U8 *RandVocabWord()
{//Walks the lst the way $LK,"ACDWordsLoad",A="MN:ACDWordsLoad"$() does, so an entry
//that lost its ACD_WORD_CHAR does not end the walk.
  I64 i;
  U8 *ptr=acd.word_lst,*end;
  if (!acd.num_words || !ptr)
    return NULL;
  end=ptr+acd.word_lst_size;
  i=RandU32%acd.num_words;
  while (ptr<end) {
    if (*ptr==ACD_WORD_CHAR)
      ptr++;
    if (!i--)
      break;
    ptr+=StrLen(ptr)+3;
  }
  if (ptr>=end || !*ptr)
    return NULL;
  else
    return ptr;
}

U8 *RandVocabWordDef()
{//A random word that the dictionary can define.
  I64 i;
  U8 *res=NULL,*def;
  for (i=0;i<256;i++)
    if (res=RandVocabWord) {
      if (def=ACDDefGet(res)) {
	Free(def);
	break;
      }
    }
  return res;
}

U8 *VocabQuizPrompt(U8 *right_word)
{//AntichristOS: the word is shown backmasked.  MAlloc()ed DolDoc.
  U8 *rev=StrMirror(right_word),*res;
  res=MStrPrint("$$WW,1$$$$CM-LE,4$$$$DKGRAY$$Unscramble the backmask:$$FG$$\n"
	"$$RED$$$$BK,1$$%s$$BK,0$$:$$FG$$$$LM,4$$\n",rev);
  Free(rev);
  return res;
}

U0 VocabQuiz()
{
  I64 ch,i,num;
  U8 *right_word,*words[4],*st;
  if (!FileFind(ACD_DEF_FILENAME)) {
    "Uncompressed dictionary not present.\n";
    return;
  }
  do {
    right_word=RandVocabWordDef;
    for (i=0;i<4;i++)
      words[i]=RandVocabWordDef;
    num=RandU32&3;
    words[num]=right_word;

    st=VocabQuizPrompt(right_word);
    "%s",st;
    Free(st);
    for (i=0;i<4;i++)
      "\n\n$$GREEN$$$$BT-X,\"%d\",LM=\"%d\"$$$$FG$$"
	    "$$LM,7$$%s\n$$LM,4$$",i+1,i+1,ACDDefGet(words[i]);
    "\n\n$$LTBLUE$$Answer:$$FG$$";
    do {
      ch=GetKey(,TRUE);
      DocBottom;
      if ('1'<=ch<='4') {
	'\n';
	if (ch-'1'==num) {
	  "$$LTGREEN$$Correct.  The Adversary approves.\n$$FG$$";
	  Snd(74);	//A falling tritone: diabolus in musica.
	  Sleep(250);
	  Snd(68);
	  Sleep(250);
	} else {
	  "$$LTRED$$Incorrect.  Your punishment: a cheerful major chord.\n$$FG$$";
	  Play("5etCEG6qC");
	}
	Snd;
	ACDPopUpDef(right_word);
	break;
      }
    } while (ch!=CH_SHIFT_ESC && ch!=CH_ESC);
    "$$LM,0$$\n";
  } while (ch!=CH_SHIFT_ESC && ch!=CH_ESC);
}
