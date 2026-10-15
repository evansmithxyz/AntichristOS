//A semordnilap is a word that spells another word backwards:
//evil/live, god/dog, lived/devil, rood/door.  ("Semordnilap" is
//"palindromes" backwards.)  The backmasking crowd swore these were
//hidden in every record.  This demo hunts for them in the Bible,
//using every core.  Compare with $LK,"::/Demo/MultiCore/Palindrome.HC"$.

#define SEM_WORD_MAX	32
#define SEM_WORDS_MAX	0x8000

CHashTable *sem_tbl=NULL;
U8 **sem_words=NULL;
I64 *sem_cnts=NULL,		//How many times each word appears.
	*sem_match=NULL,	//Idx of the reversed word or -1.
	sem_num_words=0,sem_num_pairs=0,sem_num_palindromes=0,
	sem_mp_not_done_flags,sem_min_len,
	sem_cpu_cnts[MP_PROCESSORS_NUM];

U0 SemDel()
{
  I64 i;
  if (sem_tbl) HashTableDel(sem_tbl);
  sem_tbl=NULL;
  for (i=0;i<sem_num_words;i++)
    Free(sem_words[i]);
  Free(sem_words);
  Free(sem_cnts);
  Free(sem_match);
  sem_words=NULL;
  sem_cnts=sem_match=NULL;
  sem_num_words=sem_num_pairs=sem_num_palindromes=0;
}

U0 SemWordAdd(U8 *w)
{
  CHashGeneric *tmph;
  if (tmph=HashFind(w,sem_tbl,HTT_FRAME_PTR))
    sem_cnts[tmph->user_data0]++;
  else if (sem_num_words<SEM_WORDS_MAX) {
    tmph=CAlloc(sizeof(CHashGeneric));
    tmph->str=StrNew(w);
    tmph->type=HTT_FRAME_PTR;
    tmph->user_data0=sem_num_words;
    HashAdd(tmph,sem_tbl);
    sem_words[sem_num_words]=StrNew(w);
    sem_cnts[sem_num_words++]=1;
  }
}

U0 SemTokenize(U8 *buf)
{//Lower case words of at least sem_min_len letters.
  U8 w[SEM_WORD_MAX+1];
  I64 ch,len=0;
  do {
    ch=*buf++;
    if ('A'<=ch<='Z')
      ch+='a'-'A';
    if ('a'<=ch<='z') {
      if (len<SEM_WORD_MAX)
	w[len++]=ch;
    } else {
      if (sem_min_len<=len<SEM_WORD_MAX) {
	w[len]=0;
	SemWordAdd(w);
      }
      len=0;
    }
  } while (ch);
}

U0 MPSemordnilap(I64 dummy=0)
{//Each core takes every mp_cnt-th word.  The table is only read here.
  no_warn dummy;
  I64 i,j,n;
  U8 rev[SEM_WORD_MAX+1];
  CHashGeneric *tmph;
  for (i=Gs->num;i<sem_num_words;i+=mp_cnt) {
    n=StrLen(sem_words[i]);
    for (j=0;j<n;j++)
      rev[j]=sem_words[i][n-1-j];
    rev[n]=0;
    if (tmph=HashFind(rev,sem_tbl,HTT_FRAME_PTR)) {
      sem_match[i]=tmph->user_data0;
      sem_cpu_cnts[Gs->num]++;
    }
  }
  LBtr(&sem_mp_not_done_flags,Gs->num);
}

I64 Semordnilap(U8 *filename=BIBLE_FILENAME,I64 min_len=3,Bool show=TRUE)
{//Returns the number of semordnilap pairs found.
  I64 i,size;
  U8 *buf,*name;
  F64 t0=tS;
  SemDel;
  sem_min_len=ClampI64(min_len,2,SEM_WORD_MAX-1);
  if (!(name=BibleFileFind(filename))) {
    "Can't find %s\n",filename;
    return 0;
  }
  buf=FileRead(name,&size);
  Free(name);
  sem_tbl=HashTableNew(0x8000);
  sem_words=MAlloc(SEM_WORDS_MAX*sizeof(U8 *));
  sem_cnts=MAlloc(SEM_WORDS_MAX*sizeof(I64));
  sem_match=MAlloc(SEM_WORDS_MAX*sizeof(I64));
  SemTokenize(buf);
  Free(buf);
  for (i=0;i<sem_num_words;i++)
    sem_match[i]=-1;

  MemSet(sem_cpu_cnts,0,sizeof(sem_cpu_cnts));
  sem_mp_not_done_flags=1<<mp_cnt-1;
  for (i=0;i<mp_cnt;i++)
    JobQue(&MPSemordnilap,NULL,i);
  while (sem_mp_not_done_flags)
    Yield;

  for (i=0;i<sem_num_words;i++)
    if (sem_match[i]==i)
      sem_num_palindromes++;
    else if (sem_match[i]>=0 &&
	  StrCmp(sem_words[i],sem_words[sem_match[i]])<0) {
      sem_num_pairs++;
      if (show)
	"$$RED$$%-10s$$FG$$%6d  <->  $$RED$$%-10s$$FG$$%6d\n",
	      sem_words[i],sem_cnts[i],
	      sem_words[sem_match[i]],sem_cnts[sem_match[i]];
    }
  if (show) {
    "\n";
    for (i=0;i<mp_cnt;i++)
      "CPU%02X backmasked %d words.\n",i,sem_cpu_cnts[i];
    "\n%d different words, $$RED$$%d TRUE BACKMASKs$$FG$$, "
	  "%d palindromes.\nTime:%9.5f\n",
	  sem_num_words,sem_num_pairs,sem_num_palindromes,tS-t0;
  }
  return sem_num_pairs;
}

Bool SemordnilapPair(U8 *a,U8 *b)
{//After Semordnilap(): did it find a and b as a pair?
  CHashGeneric *tmph;
  if (sem_tbl && (tmph=HashFind(a,sem_tbl,HTT_FRAME_PTR)) &&
	sem_match[tmph->user_data0]>=0)
    return !StrCmp(sem_words[sem_match[tmph->user_data0]],b);
  return FALSE;
}

Semordnilap;
