//TestUnholyC4.HC: the reviewer's independent, adversarial test of
//unless/until/do..until/backwards.  Needs the rebuilt Compiler.BIN.
//The M* functions are GENERATED: every condition is compiled
//  unless (c) A; else B;   and  if (!(c)) A; else B;
//  until (c) S             and  while (!(c)) S
//  do S until (c);         and  do S while (!(c));
//and run over a grid of I64/U64/F64/pointer values, so the
//optimizer's branch fusions are exercised with the sense flipped.
//Also: side effects, switch/try interplay, backwards corner cases,
//.UC fallback corner cases, AOT Cmp() of Unholy C, the prompt.
//forge.py run Hellforge/guest/TestUnholyC4.HC

I64 uc_pass=0,uc_fail=0;

U0 UcCheck(U8 *name,I64 got,I64 want)
{
  if (got==want) {
    uc_pass++;
    HfPrint("PASS %s = %d\n",name,got);
  } else {
    uc_fail++;
    HfPrint("FAIL %s got %d want %d\n",name,got,want);
  }
}

U0 UcCheckStr(U8 *name,U8 *got,U8 *want)
{
  if (got && !StrCmp(got,want)) {
    uc_pass++;
    HfPrint("PASS %s = \"%Q\"\n",name,got);
  } else {
    uc_fail++;
    HfPrint("FAIL %s got \"%Q\" want \"%Q\"\n",name,got,want);
  }
}

I64 UcEval(U8 *exp)
{
  I64 res=-0x666;
  try
    res=ExePrint("%s;",exp);
  catch {
    HfPrint("(expected?) EXCEPT in UcEval(%Q)\n",exp);
    Fs->catch_except=TRUE;
  }
  return res;
}

Bool UcDocHas(U8 *needle)
{
  U8 *st=DocSave(DocPut);
  Bool res=ToBool(StrMatch(needle,st));
  Free(st);
  return res;
}

U0 UcWrite(U8 *name,U8 *src)
{
  FileWrite(name,src,StrLen(src));
}

I64 va[7]={-2,-1,0,1,2,3,5};
U64 vu[4]={0,4,6,0xFFFFFFFFFFFFFFFF};
F64 vf[4]={0.0,0.25,1.0,-1.0};
U8 *vp[3]={NULL,"x",""};

I64 M0(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a) r|=1; else r|=2;
  if (!(a)) r|=4; else r|=8;
  unless (a) r|=16;
  if (!(a)) r|=32;
  until (a) {if (++n>=3) break;}
  while (!(a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a);
  do {if (++y>=3) break;} while (!(a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M1(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!a) r|=1; else r|=2;
  if (!(!a)) r|=4; else r|=8;
  unless (!a) r|=16;
  if (!(!a)) r|=32;
  until (!a) {if (++n>=3) break;}
  while (!(!a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!a);
  do {if (++y>=3) break;} while (!(!a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M2(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!!a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!!a) r|=1; else r|=2;
  if (!(!!a)) r|=4; else r|=8;
  unless (!!a) r|=16;
  if (!(!!a)) r|=32;
  until (!!a) {if (++n>=3) break;}
  while (!(!!a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!!a);
  do {if (++y>=3) break;} while (!(!!a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M3(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a==b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a==b) r|=1; else r|=2;
  if (!(a==b)) r|=4; else r|=8;
  unless (a==b) r|=16;
  if (!(a==b)) r|=32;
  until (a==b) {if (++n>=3) break;}
  while (!(a==b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a==b);
  do {if (++y>=3) break;} while (!(a==b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M4(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a!=b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a!=b) r|=1; else r|=2;
  if (!(a!=b)) r|=4; else r|=8;
  unless (a!=b) r|=16;
  if (!(a!=b)) r|=32;
  until (a!=b) {if (++n>=3) break;}
  while (!(a!=b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a!=b);
  do {if (++y>=3) break;} while (!(a!=b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M5(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<b) r|=1; else r|=2;
  if (!(a<b)) r|=4; else r|=8;
  unless (a<b) r|=16;
  if (!(a<b)) r|=32;
  until (a<b) {if (++n>=3) break;}
  while (!(a<b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<b);
  do {if (++y>=3) break;} while (!(a<b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M6(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<=b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<=b) r|=1; else r|=2;
  if (!(a<=b)) r|=4; else r|=8;
  unless (a<=b) r|=16;
  if (!(a<=b)) r|=32;
  until (a<=b) {if (++n>=3) break;}
  while (!(a<=b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<=b);
  do {if (++y>=3) break;} while (!(a<=b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M7(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a>b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a>b) r|=1; else r|=2;
  if (!(a>b)) r|=4; else r|=8;
  unless (a>b) r|=16;
  if (!(a>b)) r|=32;
  until (a>b) {if (++n>=3) break;}
  while (!(a>b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a>b);
  do {if (++y>=3) break;} while (!(a>b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M8(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a>=b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a>=b) r|=1; else r|=2;
  if (!(a>=b)) r|=4; else r|=8;
  unless (a>=b) r|=16;
  if (!(a>=b)) r|=32;
  until (a>=b) {if (++n>=3) break;}
  while (!(a>=b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a>=b);
  do {if (++y>=3) break;} while (!(a>=b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M9(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!(a==b)
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!(a==b)) r|=1; else r|=2;
  if (!(!(a==b))) r|=4; else r|=8;
  unless (!(a==b)) r|=16;
  if (!(!(a==b))) r|=32;
  until (!(a==b)) {if (++n>=3) break;}
  while (!(!(a==b))) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!(a==b));
  do {if (++y>=3) break;} while (!(!(a==b)));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M10(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a&4
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a&4) r|=1; else r|=2;
  if (!(a&4)) r|=4; else r|=8;
  unless (a&4) r|=16;
  if (!(a&4)) r|=32;
  until (a&4) {if (++n>=3) break;}
  while (!(a&4)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a&4);
  do {if (++y>=3) break;} while (!(a&4));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M11(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a&b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a&b) r|=1; else r|=2;
  if (!(a&b)) r|=4; else r|=8;
  unless (a&b) r|=16;
  if (!(a&b)) r|=32;
  until (a&b) {if (++n>=3) break;}
  while (!(a&b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a&b);
  do {if (++y>=3) break;} while (!(a&b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M12(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!(a&b)
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!(a&b)) r|=1; else r|=2;
  if (!(!(a&b))) r|=4; else r|=8;
  unless (!(a&b)) r|=16;
  if (!(!(a&b))) r|=32;
  until (!(a&b)) {if (++n>=3) break;}
  while (!(!(a&b))) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!(a&b));
  do {if (++y>=3) break;} while (!(!(a&b)));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M13(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a|b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a|b) r|=1; else r|=2;
  if (!(a|b)) r|=4; else r|=8;
  unless (a|b) r|=16;
  if (!(a|b)) r|=32;
  until (a|b) {if (++n>=3) break;}
  while (!(a|b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a|b);
  do {if (++y>=3) break;} while (!(a|b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M14(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a^b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a^b) r|=1; else r|=2;
  if (!(a^b)) r|=4; else r|=8;
  unless (a^b) r|=16;
  if (!(a^b)) r|=32;
  until (a^b) {if (++n>=3) break;}
  while (!(a^b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a^b);
  do {if (++y>=3) break;} while (!(a^b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M15(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//~a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (~a) r|=1; else r|=2;
  if (!(~a)) r|=4; else r|=8;
  unless (~a) r|=16;
  if (!(~a)) r|=32;
  until (~a) {if (++n>=3) break;}
  while (!(~a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (~a);
  do {if (++y>=3) break;} while (!(~a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M16(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//-a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (-a) r|=1; else r|=2;
  if (!(-a)) r|=4; else r|=8;
  unless (-a) r|=16;
  if (!(-a)) r|=32;
  until (-a) {if (++n>=3) break;}
  while (!(-a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (-a);
  do {if (++y>=3) break;} while (!(-a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M17(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a+b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a+b) r|=1; else r|=2;
  if (!(a+b)) r|=4; else r|=8;
  unless (a+b) r|=16;
  if (!(a+b)) r|=32;
  until (a+b) {if (++n>=3) break;}
  while (!(a+b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a+b);
  do {if (++y>=3) break;} while (!(a+b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M18(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a-b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a-b) r|=1; else r|=2;
  if (!(a-b)) r|=4; else r|=8;
  unless (a-b) r|=16;
  if (!(a-b)) r|=32;
  until (a-b) {if (++n>=3) break;}
  while (!(a-b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a-b);
  do {if (++y>=3) break;} while (!(a-b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M19(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a*b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a*b) r|=1; else r|=2;
  if (!(a*b)) r|=4; else r|=8;
  unless (a*b) r|=16;
  if (!(a*b)) r|=32;
  until (a*b) {if (++n>=3) break;}
  while (!(a*b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a*b);
  do {if (++y>=3) break;} while (!(a*b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M20(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a%3
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a%3) r|=1; else r|=2;
  if (!(a%3)) r|=4; else r|=8;
  unless (a%3) r|=16;
  if (!(a%3)) r|=32;
  until (a%3) {if (++n>=3) break;}
  while (!(a%3)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a%3);
  do {if (++y>=3) break;} while (!(a%3));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M21(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a>>1
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a>>1) r|=1; else r|=2;
  if (!(a>>1)) r|=4; else r|=8;
  unless (a>>1) r|=16;
  if (!(a>>1)) r|=32;
  until (a>>1) {if (++n>=3) break;}
  while (!(a>>1)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a>>1);
  do {if (++y>=3) break;} while (!(a>>1));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M22(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a&&b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a&&b) r|=1; else r|=2;
  if (!(a&&b)) r|=4; else r|=8;
  unless (a&&b) r|=16;
  if (!(a&&b)) r|=32;
  until (a&&b) {if (++n>=3) break;}
  while (!(a&&b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a&&b);
  do {if (++y>=3) break;} while (!(a&&b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M23(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a||b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a||b) r|=1; else r|=2;
  if (!(a||b)) r|=4; else r|=8;
  unless (a||b) r|=16;
  if (!(a||b)) r|=32;
  until (a||b) {if (++n>=3) break;}
  while (!(a||b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a||b);
  do {if (++y>=3) break;} while (!(a||b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M24(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!a&&b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!a&&b) r|=1; else r|=2;
  if (!(!a&&b)) r|=4; else r|=8;
  unless (!a&&b) r|=16;
  if (!(!a&&b)) r|=32;
  until (!a&&b) {if (++n>=3) break;}
  while (!(!a&&b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!a&&b);
  do {if (++y>=3) break;} while (!(!a&&b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M25(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a&&!b||b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a&&!b||b) r|=1; else r|=2;
  if (!(a&&!b||b)) r|=4; else r|=8;
  unless (a&&!b||b) r|=16;
  if (!(a&&!b||b)) r|=32;
  until (a&&!b||b) {if (++n>=3) break;}
  while (!(a&&!b||b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a&&!b||b);
  do {if (++y>=3) break;} while (!(a&&!b||b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M26(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<b&&b<3
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<b&&b<3) r|=1; else r|=2;
  if (!(a<b&&b<3)) r|=4; else r|=8;
  unless (a<b&&b<3) r|=16;
  if (!(a<b&&b<3)) r|=32;
  until (a<b&&b<3) {if (++n>=3) break;}
  while (!(a<b&&b<3)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<b&&b<3);
  do {if (++y>=3) break;} while (!(a<b&&b<3));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M27(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<b||b<0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<b||b<0) r|=1; else r|=2;
  if (!(a<b||b<0)) r|=4; else r|=8;
  unless (a<b||b<0) r|=16;
  if (!(a<b||b<0)) r|=32;
  until (a<b||b<0) {if (++n>=3) break;}
  while (!(a<b||b<0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<b||b<0);
  do {if (++y>=3) break;} while (!(a<b||b<0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M28(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!(a<b||b<0)
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!(a<b||b<0)) r|=1; else r|=2;
  if (!(!(a<b||b<0))) r|=4; else r|=8;
  unless (!(a<b||b<0)) r|=16;
  if (!(!(a<b||b<0))) r|=32;
  until (!(a<b||b<0)) {if (++n>=3) break;}
  while (!(!(a<b||b<0))) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!(a<b||b<0));
  do {if (++y>=3) break;} while (!(!(a<b||b<0)));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M29(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//1<=a<=3
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (1<=a<=3) r|=1; else r|=2;
  if (!(1<=a<=3)) r|=4; else r|=8;
  unless (1<=a<=3) r|=16;
  if (!(1<=a<=3)) r|=32;
  until (1<=a<=3) {if (++n>=3) break;}
  while (!(1<=a<=3)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (1<=a<=3);
  do {if (++y>=3) break;} while (!(1<=a<=3));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M30(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<b<3
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<b<3) r|=1; else r|=2;
  if (!(a<b<3)) r|=4; else r|=8;
  unless (a<b<3) r|=16;
  if (!(a<b<3)) r|=32;
  until (a<b<3) {if (++n>=3) break;}
  while (!(a<b<3)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<b<3);
  do {if (++y>=3) break;} while (!(a<b<3));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M31(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//-1<a<=b
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (-1<a<=b) r|=1; else r|=2;
  if (!(-1<a<=b)) r|=4; else r|=8;
  unless (-1<a<=b) r|=16;
  if (!(-1<a<=b)) r|=32;
  until (-1<a<=b) {if (++n>=3) break;}
  while (!(-1<a<=b)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (-1<a<=b);
  do {if (++y>=3) break;} while (!(-1<a<=b));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M32(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//Bt(&a,1)
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (Bt(&a,1)) r|=1; else r|=2;
  if (!(Bt(&a,1))) r|=4; else r|=8;
  unless (Bt(&a,1)) r|=16;
  if (!(Bt(&a,1))) r|=32;
  until (Bt(&a,1)) {if (++n>=3) break;}
  while (!(Bt(&a,1))) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (Bt(&a,1));
  do {if (++y>=3) break;} while (!(Bt(&a,1)));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M33(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!Bt(&b,0)
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!Bt(&b,0)) r|=1; else r|=2;
  if (!(!Bt(&b,0))) r|=4; else r|=8;
  unless (!Bt(&b,0)) r|=16;
  if (!(!Bt(&b,0))) r|=32;
  until (!Bt(&b,0)) {if (++n>=3) break;}
  while (!(!Bt(&b,0))) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!Bt(&b,0));
  do {if (++y>=3) break;} while (!(!Bt(&b,0)));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M34(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u) r|=1; else r|=2;
  if (!(u)) r|=4; else r|=8;
  unless (u) r|=16;
  if (!(u)) r|=32;
  until (u) {if (++n>=3) break;}
  while (!(u)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u);
  do {if (++y>=3) break;} while (!(u));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M35(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!u
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!u) r|=1; else r|=2;
  if (!(!u)) r|=4; else r|=8;
  unless (!u) r|=16;
  if (!(!u)) r|=32;
  until (!u) {if (++n>=3) break;}
  while (!(!u)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!u);
  do {if (++y>=3) break;} while (!(!u));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M36(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u<5
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u<5) r|=1; else r|=2;
  if (!(u<5)) r|=4; else r|=8;
  unless (u<5) r|=16;
  if (!(u<5)) r|=32;
  until (u<5) {if (++n>=3) break;}
  while (!(u<5)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u<5);
  do {if (++y>=3) break;} while (!(u<5));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M37(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u>4
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u>4) r|=1; else r|=2;
  if (!(u>4)) r|=4; else r|=8;
  unless (u>4) r|=16;
  if (!(u>4)) r|=32;
  until (u>4) {if (++n>=3) break;}
  while (!(u>4)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u>4);
  do {if (++y>=3) break;} while (!(u>4));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M38(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u>=6
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u>=6) r|=1; else r|=2;
  if (!(u>=6)) r|=4; else r|=8;
  unless (u>=6) r|=16;
  if (!(u>=6)) r|=32;
  until (u>=6) {if (++n>=3) break;}
  while (!(u>=6)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u>=6);
  do {if (++y>=3) break;} while (!(u>=6));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M39(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u&2
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u&2) r|=1; else r|=2;
  if (!(u&2)) r|=4; else r|=8;
  unless (u&2) r|=16;
  if (!(u&2)) r|=32;
  until (u&2) {if (++n>=3) break;}
  while (!(u&2)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u&2);
  do {if (++y>=3) break;} while (!(u&2));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M40(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u==0xFFFFFFFFFFFFFFFF
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u==0xFFFFFFFFFFFFFFFF) r|=1; else r|=2;
  if (!(u==0xFFFFFFFFFFFFFFFF)) r|=4; else r|=8;
  unless (u==0xFFFFFFFFFFFFFFFF) r|=16;
  if (!(u==0xFFFFFFFFFFFFFFFF)) r|=32;
  until (u==0xFFFFFFFFFFFFFFFF) {if (++n>=3) break;}
  while (!(u==0xFFFFFFFFFFFFFFFF)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u==0xFFFFFFFFFFFFFFFF);
  do {if (++y>=3) break;} while (!(u==0xFFFFFFFFFFFFFFFF));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M41(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//u<a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (u<a) r|=1; else r|=2;
  if (!(u<a)) r|=4; else r|=8;
  unless (u<a) r|=16;
  if (!(u<a)) r|=32;
  until (u<a) {if (++n>=3) break;}
  while (!(u<a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (u<a);
  do {if (++y>=3) break;} while (!(u<a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M42(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f) r|=1; else r|=2;
  if (!(f)) r|=4; else r|=8;
  unless (f) r|=16;
  if (!(f)) r|=32;
  until (f) {if (++n>=3) break;}
  while (!(f)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f);
  do {if (++y>=3) break;} while (!(f));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M43(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!f
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!f) r|=1; else r|=2;
  if (!(!f)) r|=4; else r|=8;
  unless (!f) r|=16;
  if (!(!f)) r|=32;
  until (!f) {if (++n>=3) break;}
  while (!(!f)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!f);
  do {if (++y>=3) break;} while (!(!f));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M44(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f<0.5
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f<0.5) r|=1; else r|=2;
  if (!(f<0.5)) r|=4; else r|=8;
  unless (f<0.5) r|=16;
  if (!(f<0.5)) r|=32;
  until (f<0.5) {if (++n>=3) break;}
  while (!(f<0.5)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f<0.5);
  do {if (++y>=3) break;} while (!(f<0.5));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M45(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f>=0.0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f>=0.0) r|=1; else r|=2;
  if (!(f>=0.0)) r|=4; else r|=8;
  unless (f>=0.0) r|=16;
  if (!(f>=0.0)) r|=32;
  until (f>=0.0) {if (++n>=3) break;}
  while (!(f>=0.0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f>=0.0);
  do {if (++y>=3) break;} while (!(f>=0.0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M46(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f==1.0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f==1.0) r|=1; else r|=2;
  if (!(f==1.0)) r|=4; else r|=8;
  unless (f==1.0) r|=16;
  if (!(f==1.0)) r|=32;
  until (f==1.0) {if (++n>=3) break;}
  while (!(f==1.0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f==1.0);
  do {if (++y>=3) break;} while (!(f==1.0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M47(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f&&a
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f&&a) r|=1; else r|=2;
  if (!(f&&a)) r|=4; else r|=8;
  unless (f&&a) r|=16;
  if (!(f&&a)) r|=32;
  until (f&&a) {if (++n>=3) break;}
  while (!(f&&a)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f&&a);
  do {if (++y>=3) break;} while (!(f&&a));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M48(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a<f
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a<f) r|=1; else r|=2;
  if (!(a<f)) r|=4; else r|=8;
  unless (a<f) r|=16;
  if (!(a<f)) r|=32;
  until (a<f) {if (++n>=3) break;}
  while (!(a<f)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a<f);
  do {if (++y>=3) break;} while (!(a<f));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M49(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//f!=-1.0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (f!=-1.0) r|=1; else r|=2;
  if (!(f!=-1.0)) r|=4; else r|=8;
  unless (f!=-1.0) r|=16;
  if (!(f!=-1.0)) r|=32;
  until (f!=-1.0) {if (++n>=3) break;}
  while (!(f!=-1.0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (f!=-1.0);
  do {if (++y>=3) break;} while (!(f!=-1.0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M50(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//p
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (p) r|=1; else r|=2;
  if (!(p)) r|=4; else r|=8;
  unless (p) r|=16;
  if (!(p)) r|=32;
  until (p) {if (++n>=3) break;}
  while (!(p)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (p);
  do {if (++y>=3) break;} while (!(p));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M51(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!p
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!p) r|=1; else r|=2;
  if (!(!p)) r|=4; else r|=8;
  unless (!p) r|=16;
  if (!(!p)) r|=32;
  until (!p) {if (++n>=3) break;}
  while (!(!p)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!p);
  do {if (++y>=3) break;} while (!(!p));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M52(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//p&&*p
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (p&&*p) r|=1; else r|=2;
  if (!(p&&*p)) r|=4; else r|=8;
  unless (p&&*p) r|=16;
  if (!(p&&*p)) r|=32;
  until (p&&*p) {if (++n>=3) break;}
  while (!(p&&*p)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (p&&*p);
  do {if (++y>=3) break;} while (!(p&&*p));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M53(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//p&&*p=='x'
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (p&&*p=='x') r|=1; else r|=2;
  if (!(p&&*p=='x')) r|=4; else r|=8;
  unless (p&&*p=='x') r|=16;
  if (!(p&&*p=='x')) r|=32;
  until (p&&*p=='x') {if (++n>=3) break;}
  while (!(p&&*p=='x')) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (p&&*p=='x');
  do {if (++y>=3) break;} while (!(p&&*p=='x'));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M54(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//!p||!*p
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (!p||!*p) r|=1; else r|=2;
  if (!(!p||!*p)) r|=4; else r|=8;
  unless (!p||!*p) r|=16;
  if (!(!p||!*p)) r|=32;
  until (!p||!*p) {if (++n>=3) break;}
  while (!(!p||!*p)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (!p||!*p);
  do {if (++y>=3) break;} while (!(!p||!*p));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M55(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (0) r|=1; else r|=2;
  if (!(0)) r|=4; else r|=8;
  unless (0) r|=16;
  if (!(0)) r|=32;
  until (0) {if (++n>=3) break;}
  while (!(0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (0);
  do {if (++y>=3) break;} while (!(0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M56(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//1
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (1) r|=1; else r|=2;
  if (!(1)) r|=4; else r|=8;
  unless (1) r|=16;
  if (!(1)) r|=32;
  until (1) {if (++n>=3) break;}
  while (!(1)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (1);
  do {if (++y>=3) break;} while (!(1));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M57(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//TRUE
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (TRUE) r|=1; else r|=2;
  if (!(TRUE)) r|=4; else r|=8;
  unless (TRUE) r|=16;
  if (!(TRUE)) r|=32;
  until (TRUE) {if (++n>=3) break;}
  while (!(TRUE)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (TRUE);
  do {if (++y>=3) break;} while (!(TRUE));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M58(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//FALSE
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (FALSE) r|=1; else r|=2;
  if (!(FALSE)) r|=4; else r|=8;
  unless (FALSE) r|=16;
  if (!(FALSE)) r|=32;
  until (FALSE) {if (++n>=3) break;}
  while (!(FALSE)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (FALSE);
  do {if (++y>=3) break;} while (!(FALSE));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M59(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//2-2
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (2-2) r|=1; else r|=2;
  if (!(2-2)) r|=4; else r|=8;
  unless (2-2) r|=16;
  if (!(2-2)) r|=32;
  until (2-2) {if (++n>=3) break;}
  while (!(2-2)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (2-2);
  do {if (++y>=3) break;} while (!(2-2));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M60(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//3*0
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (3*0) r|=1; else r|=2;
  if (!(3*0)) r|=4; else r|=8;
  unless (3*0) r|=16;
  if (!(3*0)) r|=32;
  until (3*0) {if (++n>=3) break;}
  while (!(3*0)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (3*0);
  do {if (++y>=3) break;} while (!(3*0));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M61(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//BEAST
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (BEAST) r|=1; else r|=2;
  if (!(BEAST)) r|=4; else r|=8;
  unless (BEAST) r|=16;
  if (!(BEAST)) r|=32;
  until (BEAST) {if (++n>=3) break;}
  while (!(BEAST)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (BEAST);
  do {if (++y>=3) break;} while (!(BEAST));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M62(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//BEAST-666
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (BEAST-666) r|=1; else r|=2;
  if (!(BEAST-666)) r|=4; else r|=8;
  unless (BEAST-666) r|=16;
  if (!(BEAST-666)) r|=32;
  until (BEAST-666) {if (++n>=3) break;}
  while (!(BEAST-666)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (BEAST-666);
  do {if (++y>=3) break;} while (!(BEAST-666));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 M63(I64 a,I64 b,U64 u,F64 f,U8 *p)
{//a==BEAST
  I64 r=0,n=0,m=0,x=0,y=0;
  unless (a==BEAST) r|=1; else r|=2;
  if (!(a==BEAST)) r|=4; else r|=8;
  unless (a==BEAST) r|=16;
  if (!(a==BEAST)) r|=32;
  until (a==BEAST) {if (++n>=3) break;}
  while (!(a==BEAST)) {if (++m>=3) break;}
  do {if (++x>=3) break;} until (a==BEAST);
  do {if (++y>=3) break;} while (!(a==BEAST));
  if ((r&1)<<2!=(r&4) || (r&2)<<2!=(r&8) || (r&16)<<1!=(r&32) ||
	n!=m || x!=y || !(r&3) || (r&3)==3)
    return 1;
  return 0;
}

I64 MRun(I64 k,I64 a,I64 b,U64 u,F64 f,U8 *p)
{
  switch (k) {
    case 0: return M0(a,b,u,f,p);
    case 1: return M1(a,b,u,f,p);
    case 2: return M2(a,b,u,f,p);
    case 3: return M3(a,b,u,f,p);
    case 4: return M4(a,b,u,f,p);
    case 5: return M5(a,b,u,f,p);
    case 6: return M6(a,b,u,f,p);
    case 7: return M7(a,b,u,f,p);
    case 8: return M8(a,b,u,f,p);
    case 9: return M9(a,b,u,f,p);
    case 10: return M10(a,b,u,f,p);
    case 11: return M11(a,b,u,f,p);
    case 12: return M12(a,b,u,f,p);
    case 13: return M13(a,b,u,f,p);
    case 14: return M14(a,b,u,f,p);
    case 15: return M15(a,b,u,f,p);
    case 16: return M16(a,b,u,f,p);
    case 17: return M17(a,b,u,f,p);
    case 18: return M18(a,b,u,f,p);
    case 19: return M19(a,b,u,f,p);
    case 20: return M20(a,b,u,f,p);
    case 21: return M21(a,b,u,f,p);
    case 22: return M22(a,b,u,f,p);
    case 23: return M23(a,b,u,f,p);
    case 24: return M24(a,b,u,f,p);
    case 25: return M25(a,b,u,f,p);
    case 26: return M26(a,b,u,f,p);
    case 27: return M27(a,b,u,f,p);
    case 28: return M28(a,b,u,f,p);
    case 29: return M29(a,b,u,f,p);
    case 30: return M30(a,b,u,f,p);
    case 31: return M31(a,b,u,f,p);
    case 32: return M32(a,b,u,f,p);
    case 33: return M33(a,b,u,f,p);
    case 34: return M34(a,b,u,f,p);
    case 35: return M35(a,b,u,f,p);
    case 36: return M36(a,b,u,f,p);
    case 37: return M37(a,b,u,f,p);
    case 38: return M38(a,b,u,f,p);
    case 39: return M39(a,b,u,f,p);
    case 40: return M40(a,b,u,f,p);
    case 41: return M41(a,b,u,f,p);
    case 42: return M42(a,b,u,f,p);
    case 43: return M43(a,b,u,f,p);
    case 44: return M44(a,b,u,f,p);
    case 45: return M45(a,b,u,f,p);
    case 46: return M46(a,b,u,f,p);
    case 47: return M47(a,b,u,f,p);
    case 48: return M48(a,b,u,f,p);
    case 49: return M49(a,b,u,f,p);
    case 50: return M50(a,b,u,f,p);
    case 51: return M51(a,b,u,f,p);
    case 52: return M52(a,b,u,f,p);
    case 53: return M53(a,b,u,f,p);
    case 54: return M54(a,b,u,f,p);
    case 55: return M55(a,b,u,f,p);
    case 56: return M56(a,b,u,f,p);
    case 57: return M57(a,b,u,f,p);
    case 58: return M58(a,b,u,f,p);
    case 59: return M59(a,b,u,f,p);
    case 60: return M60(a,b,u,f,p);
    case 61: return M61(a,b,u,f,p);
    case 62: return M62(a,b,u,f,p);
    case 63: return M63(a,b,u,f,p);
  }
  return 1;
}

#define M_CONDS	64
U8 *m_names[M_CONDS]={
  "a",
  "!a",
  "!!a",
  "a==b",
  "a!=b",
  "a<b",
  "a<=b",
  "a>b",
  "a>=b",
  "!(a==b)",
  "a&4",
  "a&b",
  "!(a&b)",
  "a|b",
  "a^b",
  "~a",
  "-a",
  "a+b",
  "a-b",
  "a*b",
  "a%3",
  "a>>1",
  "a&&b",
  "a||b",
  "!a&&b",
  "a&&!b||b",
  "a<b&&b<3",
  "a<b||b<0",
  "!(a<b||b<0)",
  "1<=a<=3",
  "a<b<3",
  "-1<a<=b",
  "Bt(&a,1)",
  "!Bt(&b,0)",
  "u",
  "!u",
  "u<5",
  "u>4",
  "u>=6",
  "u&2",
  "u==0xFFFFFFFFFFFFFFFF",
  "u<a",
  "f",
  "!f",
  "f<0.5",
  "f>=0.0",
  "f==1.0",
  "f&&a",
  "a<f",
  "f!=-1.0",
  "p",
  "!p",
  "p&&*p",
  "p&&*p=='x'",
  "!p||!*p",
  "0",
  "1",
  "TRUE",
  "FALSE",
  "2-2",
  "3*0",
  "BEAST",
  "BEAST-666",
  "a==BEAST"};

U0 MatrixAll()
{
  I64 k,i,j,l,o,q,fails;
  for (k=0;k<M_CONDS;k++) {
    fails=0;
    for (i=0;i<7;i++)
      for (j=0;j<7;j++)
	for (l=0;l<4;l++)
	  for (o=0;o<4;o++)
	    for (q=0;q<3;q++)
	      if (MRun(k,va[i],va[j],vu[l],vf[o],vp[q])) {
		if (!fails)
		  HfPrint("  mismatch %s at a=%d b=%d u=%X f=%5.2f p=%d\n",
			m_names[k],va[i],va[j],vu[l],vf[o],q);
		fails++;
	      }
    if (fails) {
      uc_fail++;
      HfPrint("FAIL matrix [%s] %d mismatches\n",m_names[k],fails);
    } else
      uc_pass++;
  }
  HfPrint("matrix: %d conditions x 2352 value sets, 6 forms each\n",M_CONDS);
}

////////////////////////////// side effects
I64 SideU()
{
  I64 i=3,c=0;
  until (!i--)
    c++;
  c=c*10+i+1;
  i=3;
  unless (i--)
    c+=100;
  c+=i*1000000;
  i=0;
  unless (i++)
    c+=1000;
  do c+=10000;
  until (--i<0);
  return c;
}

I64 SideW()
{
  I64 i=3,c=0;
  while (!(!i--))
    c++;
  c=c*10+i+1;
  i=3;
  if (!(i--))
    c+=100;
  c+=i*1000000;
  i=0;
  if (!(i++))
    c+=1000;
  do c+=10000;
  while (!(--i<0));
  return c;
}

////////////////////////////// interplay with switch, try, goto, dangling else
I64 SwUnless(I64 x,I64 y)
{
  I64 z=0;
  switch (x) {
    case 1:
      unless (y)
	break; //Leaves the switch.
      z=1;
      break;
    default:
      z=2;
  }
  return z;
}

I64 SwUntil(I64 x)
{
  I64 z=0;
  switch (x) {
    case 1:
      until (FALSE) {
	z++;
	if (z==4)
	  break; //Leaves the until, not the switch.
      }
      z+=10;
      break;
    default:
      z=-1;
  }
  return z;
}

I64 TryUntil()
{
  I64 n=0;
  try {
    until (FALSE)
      unless (++n<5)
	throw('Unholy');
  } catch {
    if (Fs->except_ch=='Unholy')
      Fs->catch_except=TRUE;
  }
  return n;
}

I64 GotoUnless(I64 x)
{
  I64 r=1;
  unless (x)
    goto gu_skip;
  r=2;
gu_skip:
  return r;
}

I64 Dangle(I64 a,I64 b)
{
  I64 r=0;
  if (a)
    unless (b)
      r=1;
    else
      r=2;
  return r;
}

I64 UntilDoUntil()
{//An until whose body is a do..until, and an until after a do..while.
  I64 i=0,j,s=0;
  until (i==3) {
    j=0;
    do s++;
    until (++j==i+1);
    i++;
  }
  do s+=100;
  while (FALSE);
  until (s>=1000)
    s+=300;
  return s;
}

////////////////////////////// backwards corner cases
#define BK	backwards "cba"
U8 *bk_arr[3]={backwards "ab","cd",backwards "fe"};

U8 *BkLocal()
{
  U8 *s=backwards "lacol";
  return s;
}

U0 BkStmtIf(I64 x)
{
  if (x)
    backwards "\nA1X|";
  else
    backwards "\nB1X|";
}

U8 *BkDft(U8 *s=backwards "tluafed")
{
  return s;
}

////////////////////////////// run
MatrixAll;

UcCheck("side effects (unless/until/do..until)",SideU,SideW);
UcCheck("side effects value",SideU,2*1000000+21030);
UcCheck("switch: unless break (1,0)",SwUnless(1,0),0);
UcCheck("switch: unless break (1,1)",SwUnless(1,1),1);
UcCheck("switch: unless break (0,0)",SwUnless(0,0),2);
UcCheck("switch: until break",SwUntil(1),14);
UcCheck("try: throw out of until",TryUntil,5);
UcCheck("goto from unless (0)",GotoUnless(0),1);
UcCheck("goto from unless (1)",GotoUnless(1),2);
UcCheck("dangling else binds to unless (1,0)",Dangle(1,0),1);
UcCheck("dangling else binds to unless (1,1)",Dangle(1,1),2);
UcCheck("dangling else binds to unless (0,0)",Dangle(0,0),0);
UcCheck("until around do..until",UntilDoUntil,1006);

UcCheckStr("backwards via #define",BK,"abc");
UcCheckStr("backwards hex escape",backwards "\x41\x42c","cBA");
UcCheckStr("backwards dollar",backwards "a$$b","b$$a");
UcCheckStr("backwards glbl array [0]",bk_arr[0],"ba");
UcCheckStr("backwards glbl array [1]",bk_arr[1],"cd");
UcCheckStr("backwards glbl array [2]",bk_arr[2],"ef");
UcCheckStr("backwards local",BkLocal,"local");
UcCheckStr("backwards dft arg",BkDft,"default");
UcCheckStr("backwards dft arg overridden",BkDft("x"),"x");
UcCheck("backwards stmt, if branch (before)",UcDocHas("|X1A"),0);
BkStmtIf(1);
UcCheck("backwards stmt, if branch",UcDocHas("|X1A\n"),1);
UcCheck("backwards stmt, not else",UcDocHas("|X1B"),0);
BkStmtIf(0);
UcCheck("backwards stmt, else branch",UcDocHas("|X1B\n"),1);
backwards "\n|d%-d%|",17,42;
UcCheck("backwards stmt, two args",UcDocHas("|17-42|\n"),1);
UcCheckStr("backwards backwards is forwards",
	backwards backwards "devil","devil");
UcCheckStr("backwards x3",backwards backwards backwards "devil","lived");
backwards backwards "Two wrongs make a right.\n";
UcCheck("backwards backwards stmt",UcDocHas("Two wrongs make a right.\n"),1);
UcCheck("backwards backwards 5 is a clean error",
	UcEval("backwards backwards 5"),0);

U8 *st=StrRev("god",Fs);
UcCheckStr("StrRev god",st,"dog");
Free(st);
st=StrRev(NULL);
UcCheckStr("StrRev NULL",st,"");
Free(st);
Backmask("<%d>\n",9876);
UcCheck("Backmask with args",UcDocHas(">6789<"),1);
UcCheck("BEAST",BEAST,666);

////////////////////////////// .UC fallback corner cases
DirMk("B:/Unholy4");
UcWrite("B:/Unholy4/OnlyUC.UC","I64 uc4_only=1;\n");
UcEval("#include \"B:/Unholy4/OnlyUC.HC\"\n");
UcCheck("explicit .HC never falls back to .UC",
	ToBool(HashFind("uc4_only",Fs->hash_table,HTT_GLBL_VAR)),0);
UcEval("#include \"B:/Unholy4/OnlyUC.UC\"\n");
UcCheck("explicit .UC",UcEval("uc4_only"),1);

UcWrite("B:/Unholy4/Zed.UC.Z","I64 uc4_zed=26;\n");
UcEval("#include \"B:/Unholy4/Zed\"\n");
UcCheck("compressed .UC.Z fallback",UcEval("uc4_zed"),26);

UcWrite("B:/Unholy4/Inner.UC","I64 uc4_inner=6;\n");
UcWrite("B:/Unholy4/Outer.UC",
	"#summon \"Inner\"\nI64 uc4_outer=uc4_inner+1;\n");
UcWrite("B:/Unholy4/Rel.UC","I64 uc4_rel=4;\n");
Cd("B:/Unholy4");
UcEval("#include \"Rel\"\n");
UcCheck("relative fallback",UcEval("uc4_rel"),4);
UcEval("#edulcni \"Outer\"\n");
UcCheck("nested #summon/#edulcni fallback",UcEval("uc4_outer"),7);
Cd("T:/Home");

UcWrite("B:/Unholy4/Bad.UC","I64 uc4_bad=;\n");
UcEval("#include \"B:/Unholy4/Bad\"\n");
UcCheck("error position names the .UC file",UcDocHas("Bad.UC"),1);
UcCheck("error position: no .HC ghost",UcDocHas("Bad.HC"),0);

UcWrite("B:/Unholy4/E2.UC","I64 uc4_e2=2;\n");
ExeFile2("B:/Unholy4/E2");
UcCheck("ExeFile2 fallback",UcEval("uc4_e2"),2);

UcWrite("B:/Unholy4/Adm.UC","I64 uc4_adm=7;\n");
AdamFile("B:/Unholy4/Adm");
UcCheck("AdamFile extensionless .UC",
	ToBool(HashFind("uc4_adm",adam_task->hash_table,HTT_GLBL_VAR)),1);

////////////////////////////// AOT
DirMk("B:/Aot");
UcWrite("B:/Aot/Hell.PRJ",
	"#include \"::/Kernel/KernelA.HH\"\n"
	"#include \"::/Compiler/CompilerA.HH\"\n"
	"#exe {Option(OPTf_EXTERNS_TO_IMPORTS,ON);};\n"
	"#include \"::/Kernel/KernelB.HH\"\n"
	"#include \"::/Kernel/KernelC.HH\"\n"
	"#exe {Option(OPTf_EXTERNS_TO_IMPORTS,OFF);};\n"
	"I64 AotF(I64 x)\n{\n  I64 r=0;\n"
	"  unless (x) r=1; else r=2;\n"
	"  until (x>=3) {x++; r+=10;}\n"
	"  do r+=100; until (TRUE);\n"
	"  return r;\n}\n"
	"U8 aot_buf[64];\n"
	"StrPrint(aot_buf,backwards \"s% d%\",AotF(0)+1000*AotF(5),"
	"backwards \"TOA\");\n"
	"FileWrite(\"B:/Aot/Res.TXT\",aot_buf,StrLen(aot_buf));\n");
I64 aot_errs=-1;
try
  aot_errs=Cmp("B:/Aot/Hell");
catch {
  HfPrint("EXCEPT in Cmp\n");
  Fs->catch_except=TRUE;
}
UcCheck("AOT Cmp of Unholy C: errors",aot_errs,0);
UcCheck("AOT summary says Sins:",UcDocHas("Sins:0 Temptations:0"),1);
if (FileFind("B:/Aot/Hell.BIN",,FUF_Z_OR_NOT_Z)) {
  try
    Load("B:/Aot/Hell.BIN");
  catch {
    HfPrint("EXCEPT in Load\n");
    Fs->catch_except=TRUE;
  }
}
st=FileRead("B:/Aot/Res.TXT");
UcCheckStr("AOT BIN runs unless/until/do..until/backwards",st,"102131 AOT");
Free(st);

////////////////////////////// the prompt
CTask *pt=User;
Sleep(1500);
st=DocSave(DocPut(pt));
UcCheck("User prompt is T:/Home<",ToBool(StrMatch("T:/Home<",st)),1);
UcCheck("User prompt has no T:/Home>",ToBool(StrMatch("T:/Home>",st)),0);
Free(st);
HfShot("prompt");
Kill(pt);

HfPrint("SUMMARY pass=%d fail=%d\n",uc_pass,uc_fail);
if (uc_fail)
  hf_exit_code=1;
else
  hf_exit_code=0;
