#help_index "Unholy C"
/* The Unholy C runtime: backmasking builtins.

Every record played backwards hides a message.
These do the playing.  The language is documented in ::/Doc/UnholyC.DD.

This is boot-path code, so it is written in
plain spellings (no fi/esle, no unless/until).
*/

#define BEAST	666 //The Number of the Beast, Revelation 13:18.

public U8 *StrRev(U8 *src,CTask *mem_task=NULL)
{//MAlloc copy of src with its bytes reversed. "god" becomes "dog".
  I64 i,n;
  U8 *res;
  if (!src) src="";
  n=StrLen(src);
  res=MAlloc(n+1,mem_task);
  for (i=0;i<n;i++)
    res[i]=src[n-1-i];
  res[n]=0;
  return res;
}

public U0 Backmask(U8 *fmt,...)
{//Like $LK,"Print",A="MN:Print"$(), but every line plays backwards.
//Each line is reversed on its own (the '\n's stay where they are)
//and every dollar sign is doubled, so DolDoc shows it and does not obey it.
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv),*src=buf,*dst,*res,*ptr=buf;
  I64 n=0,len;
  while (*ptr)
    if (*ptr++=='$$')
      n++;
  res=dst=MAlloc(StrLen(buf)+n+1);
  while (*src) {
    ptr=src;
    while (*ptr && *ptr!='\n')
      ptr++;
    len=ptr-src;
    while (len--) {
      if (src[len]=='$$')
	*dst++='$$';
      *dst++=src[len];
    }
    if (*ptr=='\n')
      *dst++=*ptr++;
    src=ptr;
  }
  *dst=0;
  "%s",res;
  Free(res);
  Free(buf);
}
#help_index ""
