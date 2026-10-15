//$FG,4$UnlessUntil.UC$FG$: the brand-new statements of $FG,4$Unholy C$FG$.
//  $FG,4$unless$FG$ (c) S [else S]   is  if (!(c)) S [else S]
//  $FG,4$until$FG$ (c) S             is  while (!(c)) S
//  do S $FG,4$until$FG$ (c);         is  do S while (!(c));
//  $FG,4$backwards$FG$ "txet"        is  "text" (and, as a statement, prints it)
//Two wrongs make a right: backwards backwards "text" is just "text".
//The compiler does not insert a NOT: it just flips the branch, so they
//cost exactly as much as if and while.  They need the AntichristOS
//Compiler.BIN.  Run it with  #include "::/Demo/UnholyC/UnlessUntil.UC";

U0 HellfireFizzBuzz()
{//FizzBuzz, but counting down, because we are going down.
  I64 i=15;
  "$$FG,4$$Hellfire FizzBuzz, from 15 down:$$FG$$\n";
  until (!i) {
    unless (i%15)
      "Hellfire ";
    else unless (i%3)
      "Fire ";
    else unless (i%5)
      "Brimstone ";
    else
      "%d ",i;
    i--;
  }
  '\n';
}

U0 CollatzDescent(I64 n)
{//Every soul reaches the bottom eventually.  (Nobody has proved it.)
  I64 steps=0,peak=n;
  "\n$$FG,4$$The Descent of soul #%d:$$FG$$\n",n;
  until (n==1) {
    unless (n&1)
      n>>=1;
    else
      n=3*n+1;
    unless (n<=peak)
      peak=n;
    steps++;
  }
  "  It touched the bottom after %d steps, after rising as high as %d.\n",
	steps,peak;
  unless (steps*6!=BEAST)
    "  %d steps, times six, is %d.  Coincidence?  Yes.\n",steps,steps*6;
}

U0 TriangleOfTheBeast()
{//Keep adding 1+2+3+... until we hit the Number of the Beast.
  I64 i=0,sum=0;
  do {
    i++;
    sum+=i;
  } until (sum>=BEAST);
  "\n$$FG,4$$1+2+3+...+%d = %d$$FG$$, the triangle of the beast.\n",i,sum;
}

Bool IsPrime(I64 n)
{
  I64 d=2;
  unless (n>1)
    return FALSE;
  until (d*d>n) {
    unless (n%d)
      return FALSE;
    d++;
  }
  return TRUE;
}

U0 SquaresOfPrimes()
{//2^2+3^2+5^2+7^2+11^2+13^2+17^2 = ?
  I64 n=1,cnt=0,sum=0;
  "\nThe squares of the first seven primes:\n  ";
  do {
    n++;
    unless (!IsPrime(n)) {//Double negatives: a sin we permit.
      unless (!cnt)
	'+';
      "%d^2",n;
      sum+=n*n;
      cnt++;
    }
  } until (cnt==7);
  " = %d.  Yes, again.\n",sum;
}

I64 roman_vals[6]={500,100,50,10,5,1};

U0 RomanBeast(I64 n)
{//666 is DCLXVI: every Roman numeral below M, once each, in order.
  I64 i=0;
  U8 *syms=backwards "IVXLCD";
  "\nIn Roman numerals, %d is $$FG,4$$",n;
  until (i==6) {
    until (n<roman_vals[i]) {
      '' syms[i];
      n-=roman_vals[i];
    }
    i++;
  }
  "$$FG$$, every numeral below M exactly once.\n";
}

U0 UnlessUntil()
{
  backwards "\n.edis rehto eht morf olleH";
  HellfireFizzBuzz;
  CollatzDescent(27);
  TriangleOfTheBeast;
  SquaresOfPrimes;
  RomanBeast(BEAST);
  '\n';
  backwards "\n.gninnigeB ehT"; //The inverse of The End.
}

UnlessUntil;
I64 unless_until_done=BEAST;
