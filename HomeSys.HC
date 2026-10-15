//Place this file in /Home and change
//anything you want.

U0 UserStartUp()
{//Run each time a user a spawned
  DocTermNew;
  Type("::/Doc/Start.DD");
  LBts(&Fs->display_flags,DISPLAYf_SHOW);
  WinToTop;
  WinZBufUpdate;
  Dir;
}

U0 SrvStartUp()
{//Run each time a srv task is spawned.
  DocTermNew;
  LBts(&Fs->display_flags,DISPLAYf_SHOW);
  WinToTop;
  WinZBufUpdate;
}

//AntichristOS boot splash.  Colors are named for the Hellfire
//palette: WHITE is the abyss, BLUE is hellfire, YELLOW is blood.
//It lives on the persistent layer, over the windows, and its rite
//plays in its own task, so the user terminals open underneath it.
Bool summoning=FALSE; //The circle is still on the scrn.

U0 SummonBigPrint(CDC *dc,I64 x,I64 y,I64 scale,U8 *st)
{//Print with fat pixels, straight from the (unholy) font.
  I64 ch,i,j;
  U64 g;
  while (ch=*st++) {
    g=text.font[ch];
    for (j=0;j<FONT_HEIGHT;j++)
      for (i=0;i<FONT_WIDTH;i++)
	if (Bt(&g,j*FONT_WIDTH+i))
	  GrRect(dc,x+i*scale,y+j*scale,scale,scale);
    x+=FONT_WIDTH*scale;
  }
}

U0 SummoningRite(I64)
{//One pentagram line per note of B Locrian, then sound the
//tritone and banish the circle.
  CDC *dc=DCAlias(gr.dc,sys_winmgr_task); //Whole scrn, no clipping
  I64 i,cx=GR_WIDTH/2,cy=GR_HEIGHT/2,r=128,x0,y0,x1,y1;
  F64 a;
  U8 *steps="\x01\x02\x04\x06\x07",
	*motto="ereh toob ohw ey ,epoh lla nodnabA",buf[STR_LEN];
  dc->color=BLUE;
  dc->thick=3;
  for (i=0;i<5;i++) {//Inverted pentagram: one point down.
    a=-pi/2+i*2*pi/5;
    x0=cx+r*Cos(a);
    y0=cy-r*Sin(a);
    a+=4*pi/5;
    x1=cx+r*Cos(a);
    y1=cy-r*Sin(a);
    GrLine3(dc,x0,y0,0,x1,y1,0);
    Snd(Freq2Ona(246.94*2`((steps[i]-1)/12.0)));
    Sleep(130);
  }
  Snd;
  dc->thick=1;
  dc->color=WHITE; //The title gets its own slab of abyss over the windows.
  GrRect(dc,cx-12*12-12,10,12*24+24,52);
  dc->color=LTCYAN;
  GrBorder(dc,cx-12*12-12,10,cx+12*12+11,61);
  dc->color=BLUE;
  SummonBigPrint(dc,cx-12*12,16,3,"AntichristOS");
  StrPrint(buf,"%c V%4.2f  %c%c%c  Unholy C %c",CH_UNHOLY_TRIDENT,
	sys_os_version,CH_UNHOLY_FLAME,CH_UNHOLY_SKULL,CH_UNHOLY_FLAME+1,
	CH_UNHOLY_TRIDENT);
  dc->color=YELLOW;
  GrPrint(dc,cx-StrLen(buf)*FONT_WIDTH/2,46,"%s",buf);
  x0=cx-StrLen(motto)*FONT_WIDTH/2;
  y0=cy+r+48;
  dc->color=WHITE;
  GrRect(dc,x0-8,y0-4,(StrLen(motto)+2)*FONT_WIDTH,FONT_HEIGHT+8);
  dc->color=LTCYAN;
  GrPrint(dc,x0,y0,"%s",motto);
  for (i=0;i<3;i++) {//Diabolus in musica
    Snd(Freq2Ona(493.88));
    Sleep(120);
    Snd(Freq2Ona(698.46));
    Sleep(120);
  }
  Snd;
  Sleep(400);
  DCFill(dc);
  DCDel(dc);
  summoning=FALSE;
}

U0 SummoningCircle()
{//Draw the circle and its runes now.  The rite plays on in its own
//task while the terminals open.
  CDC *dc=DCAlias(gr.dc,sys_winmgr_task); //Whole scrn, no clipping
  I64 i,cx=GR_WIDTH/2,cy=GR_HEIGHT/2,r=128;
  F64 a;
  U8 *runes="AntichristOS 666 ";
  dc->color=WHITE;
  GrFillCircle(dc,cx,cy,0,2*r+88);
  dc->color=LTCYAN;
  GrCircle(dc,cx,cy,r+30);
  GrCircle(dc,cx,cy,r+28);
  GrCircle(dc,cx,cy,r+4);
  for (i=0;i<36;i++) {//Backmasked runes around the ring
    a=pi/2-i*2*pi/36;
    dc->color=YELLOW;
    if (runes[(36-i)%StrLen(runes)]=='6')
      dc->color=LTCYAN;
    GrPrint(dc,cx+(r+16)*Cos(a)-FONT_WIDTH/2,cy-(r+16)*Sin(a)-FONT_HEIGHT/2,
	  "%c",runes[(36-i)%StrLen(runes)]);
  }
  DCDel(dc);
  summoning=TRUE;
  if (mp_cnt>1)//Its own core, so the boot work can't throw it off beat.
    Spawn(&SummoningRite,NULL,"Summoning Circle",mp_cnt-1);
  else //Not Spawn(...,0): that asks Adam, who is busy right here.
    Spawn(&SummoningRite,NULL,"Summoning Circle");
}

U0 StartUpTasks()
{
  CTask *user1,*user2;
  F64 t0;
  SummoningCircle;
  user1=User;
  user2=User;
  WinToTop(user1);
  WinTileVert;
  "Boot Time:%7.3fs\n",tS;
  XTalk(user1,"Cd;#include \"Once\";\n");
  Silent;	//no output to scrn
  ACInit("/*;!*/Bible.TXT*");
  Silent(OFF); //no output to scrn
  t0=tS;
  while (summoning && tS-t0<6.0)//Adam serves once the circle is gone.
    Sleep(20);
}

StartUpTasks;

"\nAntichristOS V%4.2f\t%D %T\n\n",sys_os_version,sys_compile_time,sys_compile_time;
