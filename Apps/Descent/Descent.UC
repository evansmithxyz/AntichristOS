//DESCENT -- A Divine Comedy for the PC Speaker.
//
//You are a lost soul, falling through the nine circles of Dante's
//Inferno.  Burning ledges rise up out of the fire.  Steer through the
//gaps.  Touch a ledge and it costs you a soul.  Lose three and you are
//DAMNED.  Reach the bottom and Satan will be with you shortly.
//
//This file is written in Unholy C, which is HolyC played backwards
//on a turntable at a church picnic.  The keywords are backmasked or
//heavy-metal aliases of the ones you know (see ::/Doc/UnholyC.DD):
//
//  fi/esle       if/else           rof         for
//  elihw         while             od          do
//  legion/esac   switch/case       tluafed     default
//  forsake       break             sacrifice   return
//  tempt/repent  try/catch         #curse      #define
//  ssalc         class             foezis      sizeof
//  otherwise     else              descend     goto (naturally)
//
//The engine underneath is TempleOS by Terry A. Davis, a far kinder
//place than this game.

#curse D_CIRCLES	9	//Limbo .. Treachery
#curse D_LEDGES_PER	12	//Ledges per circle
#curse D_LEDGES_MAX	16
#curse D_BOUNDS_MAX	4
#curse D_SOUL_Y		150	//The soul hangs here; Hell scrolls up.
#curse D_LEDGE_T	16	//Ledge thickness
#curse D_SPACING	150	//Pixels between ledges
#curse D_FATHOM		16	//Pixels per fathom (six feet under, per unit)
#curse D_EMBERS		96
#curse D_SPARKS		72
#curse D_TRAIL		12
#curse D_ARROWS		5
#curse D_STREAKS	32
#curse D_LIVES		3
#curse D_PI		3.14159265358979

//Fire automaton (a la the PSX Doom fire), drawn in 4x3 cells.
#curse D_FIRE_W		160
#curse D_FIRE_H		64
#curse D_FIRE_CW	4
#curse D_FIRE_CH	3
#curse D_HEAT_MAX	36

//Palette slots.  Every circle reprograms all 16 of them.
#curse D_BG		0
#curse D_FAR		1
#curse D_NEAR		2
#curse D_F1		3	//Fire, coolest ...
#curse D_F2		4
#curse D_F3		5
#curse D_F4		6
#curse D_F5		7	//... hottest
#curse D_LEDGE		8
#curse D_HILITE		9
#curse D_SOUL		10
#curse D_AURA		11
#curse D_ACCENT		12
#curse D_TEXT		13
#curse D_HAZARD		14
#curse D_WHITE		15

//The circles, in order of decreasing respectability.
#curse D_LIMBO		0
#curse D_LUST		1
#curse D_GLUTTONY	2
#curse D_GREED		3
#curse D_WRATH		4
#curse D_HERESY		5
#curse D_VIOLENCE	6
#curse D_FRAUD		7
#curse D_TREACHERY	8
#curse D_PAL_TITLE	9
#curse D_PAL_BOTTOM	10

//Game states
#curse D_ST_TITLE	0
#curse D_ST_PLAY	1
#curse D_ST_BOTTOM	2
#curse D_ST_DEAD	3

RegDft("TempleOS/Descent","I64 dsc_best_depth=0;\nI64 dsc_best_circle=0;\n");
RegExe("TempleOS/Descent");

U8 *dsc_names[D_CIRCLES]={"LIMBO","LUST","GLUTTONY","GREED","WRATH",
	"HERESY","VIOLENCE","FRAUD","TREACHERY"};
U8 *dsc_roman[D_CIRCLES+2]={"I","II","III","IV","V","VI","VII","VIII","IX",
	"X","XI"};
U8 *dsc_quip[D_CIRCLES]={
	"Virtuous pagans.  Great library.  No WiFi.",
	"The infernal hurricane, which never rests.",
	"Eternal rain, cold and heavy.  Cerberus has the buffet.",
	"Hoarders and wasters, rolling weights forever.",
	"The Styx.  Furious souls brawling in the mud.",
	"Flaming tombs of the heretics.  Lids are open.",
	"Phlegethon, the river of boiling blood.",
	"Malebolge.  Ten ditches of liars and flatterers.",
	"Cocytus.  A frozen lake.  Hell's coldest take."};
U8 *dsc_hint[D_CIRCLES]={
	"No torment here.  Only sighs.  Fall through.",
	"Mind the wind.  It is very passionate.",
	"You feel heavier.  Steering is sluggish.",
	"The gaps are on the move.  Follow the money.",
	"Everything shakes.  Try not to take it personally.",
	"Two ways down.  The burning one is a lie.",
	"Centaurs are taking potshots.  Dodge the arrows.",
	"Your controls are lying.  So is that other soul.",
	"Ice.  You will slide.  Traitors always do."};
U8 *dsc_ouch[8]={
	"Singed!",
	"That ledge was load-bearing.",
	"Pain is temporary.  Hell is eternal.",
	"Dante had a guide.  You have arrow keys.",
	"Brimstone 1, You 0.",
	"Ow.  Even the damned have feelings.",
	"Your soul has been lightly toasted.",
	"That one is going on your permanent record."};
U8 *dsc_epitaph[6]={
	"Here lies a soul.  Briefly.",
	"Rest in pieces.",
	"Gone to a better place.  Just kidding.",
	"Lasciate ogne speranza.  You did.",
	"Should have read the terms and conditions.",
	"Abandoned all hope, as instructed."};
U8 *dsc_riffs[3]={
	"3eEsEEeEsEEeGsEEeA#sEEeEsEEeEsEEeFsEEeEsDD",
	"3eEsEEeA#sEEeGsEEeFsEEeEsEEeA#sA#A#eBsBBeA#sGG",
	"3sEE4E3EE4D3EE4C3EE3B3EE3A#3EE3B3EE4C3EE4D"};

//Sixteen colors per circle: R,G,B (8 bits each), in palette slot order.
U8 dsc_pal[(D_CIRCLES+2)*48]={
//Limbo: grey sighs
 10,10,18,  26,26,40,  42,42,62,  50,44,60,  90,80,100, 140,125,140,
 190,180,190, 235,230,235, 72,72,96, 160,160,195, 220,238,255, 120,160,230,
 205,205,240, 165,165,200, 130,130,170, 255,255,255,
//Lust: bruised violet
 22,2,22,  52,10,52,  84,20,76,  90,0,60,  160,20,100, 220,60,140,
 255,120,190, 255,215,240, 112,30,92, 235,125,205, 225,238,255, 255,120,205,
 255,95,185, 235,175,225, 255,185,235, 255,255,255,
//Gluttony: sickly slush
 10,14,6,  30,36,16,  50,58,26,  60,50,10,  110,90,20, 160,140,30,
 205,195,60, 240,240,150, 82,72,30, 165,155,72, 225,238,255, 175,205,95,
 195,225,80, 185,195,125, 150,165,130, 255,255,255,
//Greed: molten gold
 16,10,0,  46,32,6,  74,52,10,  100,50,0,  170,100,0, 220,160,20,
 255,210,60, 255,250,190, 122,92,22, 255,215,80, 225,238,255, 255,200,60,
 255,215,40, 235,205,125, 255,230,90, 255,255,255,
//Wrath: Styx mud and rage
 16,6,8,  42,20,24,  64,30,30,  90,10,10,  150,20,10, 210,50,20,
 250,100,40, 255,200,120, 74,42,40, 205,85,62, 225,238,255, 255,85,60,
 255,55,30, 225,145,125, 125,95,72, 255,255,255,
//Heresy: classic hellfire
 14,5,0,  42,17,4,  66,28,8,  100,10,0,  180,40,0, 240,100,0,
 255,170,30, 255,240,160, 84,62,52, 175,145,122, 225,238,255, 255,145,40,
 255,125,0, 240,185,125, 255,205,80, 255,255,255,
//Violence: boiling blood
 20,0,0,  52,0,4,  84,6,10,  90,0,0,  150,0,10, 210,20,20,
 255,60,40, 255,170,140, 112,20,20, 222,62,52, 225,238,255, 255,62,62,
 255,35,35, 240,155,150, 232,222,200, 255,255,255,
//Fraud: witchfire
 4,10,12,  14,30,34,  24,48,52,  0,60,40,  0,120,80, 40,190,120,
 120,240,170, 220,255,230, 30,72,72, 100,205,182, 225,238,255, 80,255,200,
 60,255,180, 150,225,205, 180,255,220, 255,255,255,
//Treachery: frozen fire
 2,6,18,  12,26,52,  24,44,82,  20,40,90,  40,80,160, 80,140,220,
 150,200,255, 230,245,255, 122,172,222, 232,246,255, 255,250,240, 160,210,255,
 150,222,255, 190,222,250, 222,240,255, 255,255,255,
//Title: the gate of Hell
 12,2,0,  40,10,4,  64,20,6,  110,10,0,  190,40,0, 245,105,0,
 255,175,35, 255,240,170, 90,40,20, 200,120,60, 225,238,255, 255,145,40,
 255,140,0, 240,190,140, 255,210,90, 255,255,255,
//The bottom: ice, with a red Satan
 2,6,18,  12,26,52,  24,44,82,  20,40,90,  40,80,160, 80,140,220,
 150,200,255, 230,245,255, 122,172,222, 232,246,255, 225,238,255, 160,210,255,
 210,30,30, 190,222,250, 235,200,60, 255,255,255};

ssalc CDscLedge
{
  F64 wy;		//World y of the top edge
  F64 gx,gw;		//Gap
  F64 fx;		//Heresy: the false (burning) gap, or -1
  F64 slide_amp,slide_ph; //Greed: sliding gap
  I64 circle,seed;
  Bool active,hit,passed;
};

CDscLedge dsc_ledges[D_LEDGES_MAX];
F64 dsc_bound_wy[D_BOUNDS_MAX];
I64 dsc_bound_c[D_BOUNDS_MAX];
Bool dsc_bound_on[D_BOUNDS_MAX];

F64 dsc_ex[D_EMBERS],dsc_ey[D_EMBERS],dsc_evx[D_EMBERS],dsc_evy[D_EMBERS],
	dsc_elife[D_EMBERS],dsc_emax[D_EMBERS];
F64 dsc_px[D_SPARKS],dsc_py[D_SPARKS],dsc_pvx[D_SPARKS],dsc_pvy[D_SPARKS],
	dsc_plife[D_SPARKS];
I64 dsc_pc[D_SPARKS];
F64 dsc_ax[D_ARROWS],dsc_awy[D_ARROWS],dsc_avx[D_ARROWS];
Bool dsc_aon[D_ARROWS];
F64 dsc_sx[D_STREAKS],dsc_sy[D_STREAKS],dsc_slen[D_STREAKS];
F64 dsc_trail[D_TRAIL];
I64 dsc_trail_i;

U8 dsc_fire[D_FIRE_W*D_FIRE_H];
I64 dsc_heat_color[D_HEAT_MAX+8];
CDC *dsc_fire_dc;
U64 dsc_rng=0x666;

I64 dsc_state,dsc_circle,dsc_loop,dsc_lives,dsc_frame,dsc_w=640,dsc_h=472;
I64 dsc_spawn_circle,dsc_spawned_in,dsc_pal_target,dsc_last_fathoms;
F64 dsc_depth,dsc_speed,dsc_speed_target,dsc_x,dsc_vx,dsc_next_wy,
	dsc_prev_gap_c,dsc_banner_t0,dsc_state_t0,dsc_invuln_until,
	dsc_dying_t,dsc_flash,dsc_shake,dsc_wind,dsc_last_t,dsc_arrow_t,
	dsc_pop_t0,dsc_msg_until,dsc_title_a,
	dsc_t;	//Game clock, in seconds.  Hell stands still while paused.
I64 dsc_msg_dir,dsc_shake_x,dsc_shake_y;
F64 dsc_pal_cur[48];
U8 dsc_pop_buf[STR_LEN];
Bool dsc_quit,dsc_paused,dsc_mute,dsc_cheated,dsc_deal,dsc_new_record,
	dsc_hit_666;

//PC speaker sound effects, sequenced from the game loop (no Sleep).
#curse D_SFX_MAX	16
I64 dsc_sfx_ona[D_SFX_MAX],dsc_sfx_n,dsc_sfx_i;
F64 dsc_sfx_dur[D_SFX_MAX],dsc_sfx_next;
Bool dsc_sfx_on,dsc_song_held;
CTask *dsc_task;
I64 dsc_prof[10],dsc_prof_n,dsc_prof_t;
U0 DscProf(I64 i)
{
  I64 t=GetTSC;
  dsc_prof[i]+=t-dsc_prof_t;
  dsc_prof_t=t;
}

/////////////////////////////// Utilities ///////////////////////////////

I64 DscRand()
{//Our own LCG.  Cheaper than RandU16 for 10,000 fire cells a frame.
  dsc_rng=dsc_rng*6364136223846793005+1442695040888963407;
  sacrifice dsc_rng>>33;
}

I64 DscHash(I64 a,I64 b,I64 c)
{
  sacrifice ((a*73856093)^(b*19349663)^(c*83492791))>>4&0xFFFF;
}

U0 DscCText(CDC *dc,I64 y,I64 color,U8 *st)
{//Print centered, 8x8 font.
  dc->color=color;
  GrPrint(dc,(dsc_w-StrLen(st)*FONT_WIDTH)/2,y,"%s",st);
}

U0 DscBig(CDC *dc,I64 x,I64 y,U8 *st,I64 s,Bool flame=TRUE,
	I64 color=D_TEXT,Bool shimmer=FALSE)
{//Big text from the system font, one GrRect per run of lit pixels.
//Flame letters go white-hot at the top and blood-red at the bottom.
  I64 ch,row,c,c0,bits,dx,i=0;
  U64 g;
  elihw (ch=*st++) {
    g=text.font[ch];
    rof (row=0;row<8;row++) {
      bits=g.u8[row];
      fi (!bits) descend big_next_row;	//Hell has no 'continue'.
      fi (flame) {
	fi (row<2)
	  dc->color=D_F5;
	esle fi (row<4)
	  dc->color=D_F4;
	esle fi (row<6)
	  dc->color=D_F3;
	esle
	  dc->color=D_F2;
      } esle
	dc->color=color;
      dx=0;
      fi (shimmer)
	dx=ToI64(1.6*Sin(tS*5.0+row*0.9+i*0.7));
      c=0;
      elihw (c<8) {
	fi (Bt(&bits,c)) {
	  c0=c;
	  elihw (c<8 && Bt(&bits,c))
	    c++;
	  GrRect(dc,x+i*8*s+c0*s+dx,y+row*s,(c-c0)*s,s);
	} esle
	  c++;
      }
big_next_row:;
    }
    i++;
  }
}

U0 DscBigShadow(CDC *dc,I64 y,U8 *st,I64 s,Bool flame=TRUE,
	I64 color=D_TEXT,Bool shimmer=FALSE)
{//Centered big text with a scorched drop shadow.
  I64 x=(dsc_w-StrLen(st)*8*s)/2,d=s/2+1;
  DscBig(dc,x+d,y+d,st,s,FALSE,D_F1);
  DscBig(dc,x,y,st,s,flame,color,shimmer);
}

U0 DscTri(CDC *dc,I64 x1,I64 y1,I64 x2,I64 y2,I64 x3,I64 y3)
{
  CD3I32 p[3];
  p[0].x=x1; p[0].y=y1; p[0].z=0;
  p[1].x=x2; p[1].y=y2; p[1].z=0;
  p[2].x=x3; p[2].y=y3; p[2].z=0;
  GrFillPoly3(dc,3,p);
}

U0 DscPop(U8 *fmt,...)
{//A short message that floats over the abyss for a couple of seconds.
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  I64 n=MinI64(StrLen(buf),STR_LEN-1);
  MemCpy(dsc_pop_buf,buf,n);
  dsc_pop_buf[n]=0;
  Free(buf);
  dsc_pop_t0=dsc_t;
}

/////////////////////////////// Sound ///////////////////////////////////

U0 DscSfxStart()
{
  dsc_sfx_n=0;
  dsc_sfx_i=0;
}

U0 DscSfxAdd(I64 ona,F64 dur)
{
  fi (dsc_sfx_n<D_SFX_MAX) {
    dsc_sfx_ona[dsc_sfx_n]=ona;
    dsc_sfx_dur[dsc_sfx_n]=dur;
    dsc_sfx_n++;
  }
}

U0 DscSongSync()
{//The hymn holds its breath for sound effects, pauses and mute.
  Bool hold=dsc_mute || dsc_paused || dsc_sfx_on;
  fi (dsc_task->song_task && hold!=dsc_song_held) {
    Suspend(dsc_task->song_task,hold);
    dsc_song_held=hold;
  }
  fi (hold && !dsc_sfx_on)
    Snd;
}

U0 DscSfxGo()
{
  dsc_sfx_next=0;
  dsc_sfx_on=TRUE;
  DscSongSync;
}

U0 DscSfxTick()
{
  fi (!dsc_sfx_on || tS<dsc_sfx_next) sacrifice;
  fi (dsc_sfx_i<dsc_sfx_n) {
    fi (!dsc_mute)
      Snd(dsc_sfx_ona[dsc_sfx_i]);
    dsc_sfx_next=tS+dsc_sfx_dur[dsc_sfx_i];
    dsc_sfx_i++;
  } esle {
    Snd;
    dsc_sfx_on=FALSE;
    DscSongSync;
  }
}

U0 DscSting(I64 ona)
{//The tritone: diabolus in musica.  Root, then six semitones up.
  DscSfxStart;
  DscSfxAdd(ona,0.15);
  DscSfxAdd(0,0.03);
  DscSfxAdd(ona+6,0.40);
  DscSfxGo;
}

U0 DscSongTask(I64)
{//Hymn of the Damned.  Gallops in E, leans on the tritone.
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  elihw (TRUE) {
    fi (dsc_state==D_ST_PLAY) {
      music.tempo=Min(6.0,2.4+0.22*dsc_circle+0.35*dsc_loop);
      Play(dsc_riffs[dsc_circle%3]);
    } esle fi (dsc_state==D_ST_BOTTOM) {
      music.tempo=2.0;
      Play("2hE3hA#2hD#3hA");
    } esle {
      music.tempo=2.2;
      Play("2qE2eEE3qA#2eEE2qE2eEE3qA2qG#");
    }
  }
}

/////////////////////////////// Palette /////////////////////////////////

U0 DscPalSnap(I64 p)
{
  I64 i;
  rof (i=0;i<48;i++)
    dsc_pal_cur[i]=dsc_pal[p*48+i];
  dsc_pal_target=p;
}

U0 DscPalTick(F64 dt)
{//Cross-fade toward the target circle's palette, plus hit flashes.
  I64 i,r,g,b;
  F64 k=Min(1.0,dt*2.5),f=dsc_flash;
  CBGR48 c;
  rof (i=0;i<48;i++)
    dsc_pal_cur[i]+=(dsc_pal[dsc_pal_target*48+i]-dsc_pal_cur[i])*k;
  rof (i=0;i<16;i++) {
    r=dsc_pal_cur[i*3];
    g=dsc_pal_cur[i*3+1];
    b=dsc_pal_cur[i*3+2];
    fi (i==D_BG && f>0) {
      r=r+(170-r)*f;
      g=g*(1.0-f);
      b=b*(1.0-f);
    }
    c.r=ClampI64(r,0,255)*257;
    c.g=ClampI64(g,0,255)*257;
    c.b=ClampI64(b,0,255)*257;
    c.pad=0;
    GrPaletteColorSet(i,c);
  }
}

/////////////////////////////// Fire ////////////////////////////////////

U0 DscFireInit()
{
  I64 i;
  MemSet(dsc_fire,0,foezis(dsc_fire));
  rof (i=0;i<D_HEAT_MAX+8;i++) {
    fi (i<5)
      dsc_heat_color[i]=TRANSPARENT;
    esle fi (i<10)
      dsc_heat_color[i]=D_F1;
    esle fi (i<16)
      dsc_heat_color[i]=D_F2;
    esle fi (i<22)
      dsc_heat_color[i]=D_F3;
    esle fi (i<29)
      dsc_heat_color[i]=D_F4;
    otherwise	//Metal spelling of esle.
      dsc_heat_color[i]=D_F5;
  }
}

U0 DscFireStep(I64 decay_mask,I64 base)
{//Each cell copies the one below it, drifts sideways and cools a bit.
  I64 x,y,r,h,dst;
  U8 *f=dsc_fire;
  rof (x=0;x<D_FIRE_W;x++)
    f[(D_FIRE_H-1)*D_FIRE_W+x]=base-(DscRand&3);
  rof (y=1;y<D_FIRE_H;y++)
    rof (x=0;x<D_FIRE_W;x++) {
      r=DscRand;
      h=f[y*D_FIRE_W+x]-(r&1)-((r>>2)&decay_mask&1);
      fi (h<0) h=0;
      dst=x-((r>>4)&3)+1;
      fi (dst<0) dst=0;
      fi (dst>=D_FIRE_W) dst=D_FIRE_W-1;
      f[(y-1)*D_FIRE_W+dst]=h;
    }
}

U0 DscFireRender()
{//Straight into the bitmap, four pixels at a time.
  I64 x,y,wi=dsc_fire_dc->width_internal;
  U32 v,*p0,*p1,*p2;
  U8 *row;
  rof (y=0;y<D_FIRE_H;y++) {
    row=dsc_fire_dc->body+y*D_FIRE_CH*wi;
    p0=row;
    p1=row+wi;
    p2=row+2*wi;
    rof (x=0;x<D_FIRE_W;x++) {
      v=dsc_heat_color[dsc_fire[y*D_FIRE_W+x]]*0x01010101;
      *p0++=v;
      *p1++=v;
      *p2++=v;
    }
  }
}

/////////////////////////////// Particles ///////////////////////////////

U0 DscEmber(I64 i)
{
  dsc_ex[i]=Rand*dsc_w;
  dsc_ey[i]=dsc_h-20-Rand*90;
  dsc_evx[i]=(Rand-0.5)*40;
  dsc_evy[i]=-(50+Rand*150);
  dsc_emax[i]=dsc_elife[i]=0.8+Rand*2.0;
}

U0 DscBurst(F64 x,F64 y,I64 n,F64 power)
{
  I64 i,j=0;
  F64 a,v;
  rof (i=0;i<D_SPARKS && j<n;i++)
    fi (dsc_plife[i]<=0) {
      a=Rand*2*D_PI;
      v=power*(0.3+Rand);
      dsc_px[i]=x;
      dsc_py[i]=y;
      dsc_pvx[i]=v*Cos(a);
      dsc_pvy[i]=v*Sin(a)-power*0.5;
      dsc_plife[i]=0.6+Rand*0.9;
      legion (j%4) {
	esac 0: dsc_pc[i]=D_SOUL;  forsake;
	esac 1: dsc_pc[i]=D_AURA;  forsake;
	esac 2: dsc_pc[i]=D_F4;    forsake;
	esac 3: dsc_pc[i]=D_F5;    forsake;
      }
      j++;
    }
}

U0 DscParticlesTick(F64 dt)
{
  I64 i;
  F64 lift=0;
  fi (dsc_state==D_ST_PLAY)
    lift=dsc_speed*0.35;
  rof (i=0;i<D_EMBERS;i++) {
    dsc_elife[i]-=dt;
    fi (dsc_elife[i]<=0 || dsc_ey[i]<-4)
      DscEmber(i);
    dsc_ex[i]+=(dsc_evx[i]+30*Sin(dsc_t*3+i))*dt;
    dsc_ey[i]+=(dsc_evy[i]-lift)*dt;
  }
  rof (i=0;i<D_SPARKS;i++)
    fi (dsc_plife[i]>0) {
      dsc_plife[i]-=dt;
      dsc_pvy[i]+=320*dt;
      dsc_px[i]+=dsc_pvx[i]*dt;
      dsc_py[i]+=dsc_pvy[i]*dt;
    }
}

/////////////////////////////// The pit /////////////////////////////////

F64 DscGapX(CDscLedge *l)
{
  F64 x=l->gx;
  fi (l->slide_amp>0) {
    x+=l->slide_amp*Sin(dsc_t*1.4+l->slide_ph);
    x=Clamp(x,8.0,dsc_w-8.0-l->gw);
  }
  sacrifice x;
}

F64 DscMaxV(I64 c)
{//Top steering speed in circle c.
  fi (c==D_GLUTTONY) sacrifice 250.0;
  fi (c==D_TREACHERY) sacrifice 430.0;
  sacrifice 370.0;
}

F64 DscFallSpeed(I64 c)
{//Pixels per second.  Every circle is steeper; every loop, more so.
  sacrifice Min(560.0,135+22*c+60*dsc_loop);
}

U0 DscSpawnLedge()
{
  I64 i,c=dsc_spawn_circle;
  F64 gw,reach,center,lo,hi;
  CDscLedge *l=NULL;
  rof (i=0;i<D_LEDGES_MAX;i++)
    fi (!dsc_ledges[i].active) {
      l=&dsc_ledges[i];
      forsake;
    }
  fi (!l) sacrifice;
  MemSet(l,0,foezis(CDscLedge));
  l->active=TRUE;
  l->wy=dsc_next_wy;
  l->circle=c;
  l->seed=DscRand;
  l->fx=-1;
  gw=160-7*c-12*dsc_loop;
  fi (c==D_LIMBO) gw+=20;
  fi (gw<84) gw=84;
  l->gw=gw;

  //Keep the next gap within reach of the last one.
  //(Judged by the circle the ledge belongs to, not the one you are in.)
  reach=0.7*DscMaxV(c)*D_SPACING/DscFallSpeed(c);
  lo=Max(gw/2+12,dsc_prev_gap_c-reach);
  hi=Min(dsc_w-gw/2-12,dsc_prev_gap_c+reach);
  center=lo+Rand*(hi-lo);
  l->gx=center-gw/2;
  dsc_prev_gap_c=center;

  fi (c==D_GREED) {
    l->slide_amp=50+Rand*70;
    l->slide_ph=Rand*2*D_PI;
  }
  fi (c==D_HERESY) {//A second gap.  It is on fire.  It is a lie.
    fi (center>dsc_w/2)
      l->fx=Max(10.0,l->gx-gw-60-Rand*80);
    esle
      l->fx=Min(dsc_w-10.0-gw,l->gx+gw+60+Rand*80);
  }

  fi (++dsc_spawned_in>=D_LEDGES_PER) {
    //Circle boundary: a gate, then some room to read the banner.
    rof (i=0;i<D_BOUNDS_MAX;i++)
      fi (!dsc_bound_on[i]) {
	dsc_bound_on[i]=TRUE;
	dsc_bound_wy[i]=l->wy+D_SPACING;
	dsc_bound_c[i]=c+1;
	forsake;
      }
    dsc_spawned_in=0;
    dsc_spawn_circle=c+1;
    dsc_next_wy=l->wy+D_SPACING*2.6;
  } esle
    dsc_next_wy=l->wy+D_SPACING;
}

U0 DscClearPit()
{
  I64 i;
  rof (i=0;i<D_LEDGES_MAX;i++)
    dsc_ledges[i].active=FALSE;
  rof (i=0;i<D_BOUNDS_MAX;i++)
    dsc_bound_on[i]=FALSE;
  rof (i=0;i<D_ARROWS;i++)
    dsc_aon[i]=FALSE;
}

U0 DscEnterCircle(I64 c)
{
  dsc_circle=c;
  dsc_banner_t0=dsc_t;
  dsc_pal_target=c;
  dsc_speed_target=DscFallSpeed(c);
  dsc_arrow_t=dsc_t+1.5;
  DscSting(52-2*c);
}

U0 DscGoBottom()
{
  dsc_state=D_ST_BOTTOM;
  dsc_state_t0=dsc_t;
  dsc_pal_target=D_PAL_BOTTOM;
  DscClearPit;
  DscSfxStart;
  DscSfxAdd(30,0.3);
  DscSfxAdd(36,0.3);
  DscSfxAdd(29,0.3);
  DscSfxAdd(35,0.3);
  DscSfxAdd(28,0.7);
  DscSfxGo;
}

U0 DscStartCircleFresh(I64 c)
{//Empty the pit and begin circle c just below the screen.
  DscClearPit;
  dsc_spawn_circle=c;
  dsc_spawned_in=0;
  dsc_next_wy=dsc_depth+dsc_h-D_SOUL_Y+40;
  dsc_prev_gap_c=dsc_x;
  DscEnterCircle(c);
}

U0 DscNewGame()
{
  I64 i;
  dsc_state=D_ST_PLAY;
  dsc_state_t0=dsc_t;
  dsc_loop=0;
  dsc_lives=D_LIVES;
  dsc_depth=0;
  dsc_speed=0;
  dsc_x=dsc_w/2;
  dsc_vx=0;
  dsc_invuln_until=0;
  dsc_dying_t=0;
  dsc_cheated=dsc_deal;
  dsc_new_record=FALSE;
  dsc_hit_666=FALSE;
  dsc_last_fathoms=0;
  i=0;
  od dsc_trail[i]=dsc_x;	//od..elihw: a do..while, seen in a mirror.
  elihw (++i<D_TRAIL);
  DscStartCircleFresh(D_LIMBO);
}

U0 DscNextLoop()
{//Back to Limbo, faster, with a soul refunded for waiting in line.
  dsc_loop++;
  dsc_state=D_ST_PLAY;
  dsc_state_t0=dsc_t;
  fi (dsc_lives<5)
    dsc_lives++;
  DscStartCircleFresh(D_LIMBO);
  DscPop("LOOP %s: Abandon even more hope.  (+1 soul for waiting)",
	dsc_roman[MinI64(dsc_loop,10)]);
}

U0 DscDie()
{
  I64 fathoms=dsc_depth/D_FATHOM,deepest=dsc_circle+D_CIRCLES*dsc_loop;
  dsc_state=D_ST_DEAD;
  dsc_state_t0=dsc_t;
  dsc_pal_target=D_PAL_TITLE;
  fi (!dsc_cheated && fathoms>dsc_best_depth) {
    dsc_best_depth=fathoms;
    dsc_new_record=TRUE;
  }
  fi (!dsc_cheated && deepest>dsc_best_circle)
    dsc_best_circle=deepest;
}

U0 DscHit()
{
  dsc_lives--;
  dsc_flash=1.0;
  dsc_shake=10;
  dsc_invuln_until=dsc_t+1.6;
  DscBurst(dsc_x,D_SOUL_Y,24,160);
  DscSfxStart;
  fi (dsc_lives<=0) {
    dsc_dying_t=dsc_t;
    DscBurst(dsc_x,D_SOUL_Y,D_SPARKS,260);
    DscSfxAdd(40,0.12);
    DscSfxAdd(34,0.12);
    DscSfxAdd(28,0.12);
    DscSfxAdd(22,0.5);
    DscPop("DAMNED.");
  } esle {
    DscSfxAdd(34,0.05);
    DscSfxAdd(28,0.05);
    DscSfxAdd(22,0.10);
    DscPop("%s",dsc_ouch[DscRand&7]);
  }
  DscSfxGo;
}

U0 DscPlayTick(F64 dt)
{
  I64 i,dir,fathoms;
  F64 sy,acc,gx,maxv,damp;
  CDscLedge *l;

  dsc_speed+=(dsc_speed_target-dsc_speed)*Min(1.0,dt*1.5);
  fi (dsc_dying_t) {
    dsc_depth+=dsc_speed*0.25*dt;
    fi (dsc_t-dsc_dying_t>1.4)
      DscDie;
    sacrifice;
  }
  dsc_depth+=dsc_speed*dt;

  //Steering.  Held keys from the keyboard, or recent key messages.
  //(Held keys count only while our window has the focus; arrows typed
  //into some other window are not prayers addressed to us.)
  dir=0;
  fi (sys_focus_task==dsc_task) {
    fi (Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) dir--;
    fi (Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)) dir++;
  }
  fi (!dir && tS<dsc_msg_until) dir=dsc_msg_dir;
  fi (dsc_circle==D_FRAUD) dir=-dir;	//Lies.
  maxv=DscMaxV(dsc_circle);
  acc=2800;
  fi (dsc_circle==D_GLUTTONY) acc=1300;
  fi (dsc_circle==D_TREACHERY) acc=1500;
  dsc_vx+=dir*acc*dt;
  fi (dsc_circle==D_LUST) {
    dsc_wind=480*Sin(dsc_t*0.8)+180*Sin(dsc_t*2.3);
    dsc_vx+=dsc_wind*dt;
  } esle
    dsc_wind=0;
  damp=9.0;
  fi (dir) damp=1.5;
  fi (dsc_circle==D_TREACHERY) damp=0.35;
  dsc_vx*=Exp(-damp*dt);
  dsc_vx=Clamp(dsc_vx,-maxv,maxv);
  dsc_x+=dsc_vx*dt;
  fi (dsc_x<10) {
    dsc_x=10;
    fi (dsc_circle==D_TREACHERY) dsc_vx=-0.5*dsc_vx; esle dsc_vx=0;
  }
  fi (dsc_x>dsc_w-10) {
    dsc_x=dsc_w-10;
    fi (dsc_circle==D_TREACHERY) dsc_vx=-0.5*dsc_vx; esle dsc_vx=0;
  }
  dsc_trail_i=(dsc_trail_i+1)%D_TRAIL;
  dsc_trail[dsc_trail_i]=dsc_x;

  //Ledges rise out of the fire...
  elihw (dsc_next_wy-dsc_depth+D_SOUL_Y<dsc_h+40 &&
	dsc_spawn_circle<D_CIRCLES)
    DscSpawnLedge;

  rof (i=0;i<D_LEDGES_MAX;i++) {
    l=&dsc_ledges[i];
    fi (l->active) {
      sy=l->wy-dsc_depth+D_SOUL_Y;
      fi (sy<-60) {
	l->active=FALSE;
      } esle fi (!l->passed && sy+D_LEDGE_T<D_SOUL_Y-8) {
	l->passed=TRUE;
	fi (dsc_circle==D_WRATH)
	  dsc_shake=7;
      } esle fi (!l->passed && !l->hit && sy<D_SOUL_Y+10 &&
	    sy+D_LEDGE_T>D_SOUL_Y-8) {
	gx=DscGapX(l);
	fi (dsc_x-6<gx || dsc_x+6>gx+l->gw) {
	  l->hit=TRUE;
	  fi (dsc_t>dsc_invuln_until && !dsc_deal)
	    DscHit;
	}
      }
    }
  }

  //... and the gates between circles.
  rof (i=0;i<D_BOUNDS_MAX;i++)
    fi (dsc_bound_on[i] && dsc_depth>=dsc_bound_wy[i]) {
      dsc_bound_on[i]=FALSE;
      fi (dsc_bound_c[i]>=D_CIRCLES) {
	DscGoBottom;
	sacrifice;
      } esle
	DscEnterCircle(dsc_bound_c[i]);
    }

  //Centaur archery.
  fi (dsc_circle==D_VIOLENCE && dsc_t>dsc_arrow_t) {
    dsc_arrow_t=dsc_t+0.8+Rand*0.7;
    rof (i=0;i<D_ARROWS;i++)
      fi (!dsc_aon[i]) {
	dsc_aon[i]=TRUE;
	dsc_awy[i]=dsc_depth+dsc_h-60-Rand*220-D_SOUL_Y;
	fi (Rand<0.5) {
	  dsc_ax[i]=-20;
	  dsc_avx[i]=200+Rand*120;
	} esle {
	  dsc_ax[i]=dsc_w+20;
	  dsc_avx[i]=-200-Rand*120;
	}
	forsake;
      }
  }
  rof (i=0;i<D_ARROWS;i++)
    fi (dsc_aon[i]) {
      dsc_ax[i]+=dsc_avx[i]*dt;
      sy=dsc_awy[i]-dsc_depth+D_SOUL_Y;
      fi (sy<-20 || dsc_ax[i]<-40 || dsc_ax[i]>dsc_w+40)
	dsc_aon[i]=FALSE;
      esle fi (Abs(sy-D_SOUL_Y)<7 && Abs(dsc_ax[i]-dsc_x)<12) {
	dsc_aon[i]=FALSE;
	fi (dsc_t>dsc_invuln_until && !dsc_deal)
	  DscHit;
      }
    }

  //Wind streaks (Lust) and filthy rain (Gluttony), in screen space.
  rof (i=0;i<D_STREAKS;i++) {
    fi (dsc_circle==D_LUST) {
      dsc_sx[i]+=(dsc_wind*1.6+Sign(dsc_wind)*120)*dt;
      dsc_sy[i]-=dsc_speed*0.3*dt;
    } esle {
      dsc_sx[i]-=50*dt;
      dsc_sy[i]+=260*dt;
    }
    fi (dsc_sx[i]<-60) dsc_sx[i]+=dsc_w+120;
    fi (dsc_sx[i]>dsc_w+60) dsc_sx[i]-=dsc_w+120;
    fi (dsc_sy[i]<20) dsc_sy[i]+=dsc_h-20;
    fi (dsc_sy[i]>dsc_h) dsc_sy[i]-=dsc_h-20;
  }

  //The Number of the Beast.
  fathoms=dsc_depth/D_FATHOM;
  fi (!dsc_hit_666 && fathoms>=666) {
    dsc_hit_666=TRUE;
    DscPop("666 FATHOMS!  The Number of the Beast!  \\m/");
    DscSfxStart;
    DscSfxAdd(54,0.1);
    DscSfxAdd(60,0.1);
    DscSfxAdd(54,0.1);
    DscSfxAdd(60,0.1);
    DscSfxAdd(66,0.35);
    DscSfxGo;
  }
  dsc_last_fathoms=fathoms;
}

U0 DscTick(F64 dt)
{
  I64 decay=1,base=D_HEAT_MAX;
  dsc_frame++;
  fi (dsc_state==D_ST_TITLE)
    dsc_title_a+=dt;
  fi (dsc_state==D_ST_BOTTOM) base=24;
  dsc_prof_t=GetTSC;
  DscFireStep(decay,base);
  DscFireRender;
  DscProf(7);
  DscParticlesTick(dt);
  dsc_flash=Max(0.0,dsc_flash-dt*2.0);
  dsc_shake=Max(0.0,dsc_shake-dt*20.0);
  fi (dsc_state==D_ST_PLAY && dsc_circle==D_WRATH && dsc_shake<2.5)
    dsc_shake=2.5;
  dsc_shake_x=ToI64((Rand-0.5)*2*dsc_shake);
  dsc_shake_y=ToI64((Rand-0.5)*2*dsc_shake);
  DscPalTick(dt);
  legion (dsc_state) {
    esac D_ST_PLAY:
      DscPlayTick(dt);
      forsake;
    esac D_ST_BOTTOM:
      fi (dsc_t-dsc_state_t0>10.0)
	DscNextLoop;
      forsake;
  }
}

/////////////////////////////// Drawing /////////////////////////////////

U0 DscDrawSoul(CDC *dc,I64 x,I64 y,I64 body=D_SOUL,I64 aura=D_AURA)
{//A small screaming ghost, arms up, falling forever.
  I64 wob=(dsc_frame>>2)&1,k;
  dc->color=aura;
  GrCircle(dc,x,y+4,17+wob);
  GrCircle(dc,x,y+4,19-wob);
  dc->color=body;
  GrFillCircle(dc,x,y,0,19);
  GrRect(dc,x-9,y,19,11);
  rof (k=0;k<4;k++)	//Tattered hem, flapping in the updraft
    GrFillCircle(dc,x-7+k*5,y+11+((k+(dsc_frame>>2))&1)*2,0,5);
  rof (k=0;k<2;k++) {	//Arms flung up: the universal sign for "falling"
    GrLine(dc,x-8,y+2+k,x-15,y-9+wob*3+k);
    GrLine(dc,x+8,y+2+k,x+15,y-8-wob*3+k);
  }
  GrFillCircle(dc,x-15,y-9+wob*3,0,4);
  GrFillCircle(dc,x+15,y-8-wob*3,0,4);
  dc->color=D_BG;
  GrRect(dc,x-5,y-4,3,5);
  GrRect(dc,x+3,y-4,3,5);
  GrFillCircle(dc,x,y+5,0,5+wob);
}

U0 DscDrawMiniSoul(CDC *dc,I64 x,I64 y)
{
  dc->color=D_SOUL;
  GrFillCircle(dc,x,y,0,7);
  GrRect(dc,x-3,y,7,5);
  dc->color=D_BG;
  GrPlot(dc,x-1,y-1);
  GrPlot(dc,x+1,y-1);
}

U0 DscDrawWalls(CDC *dc)
{//Two layers of cavern rock, scrolling at different speeds.
  I64 y,wl,wr,yy;
  F64 o1=dsc_depth*0.35,o2=dsc_depth*0.7;
  dc->color=D_FAR;
  rof (y=0;y<dsc_h;y+=8) {
    yy=y+o1;
    wl=40+22*Sin(yy*0.011)+12*Sin(yy*0.037+1.3)+6*Sin(yy*0.093);
    wr=40+22*Sin(yy*0.013+2.0)+12*Sin(yy*0.041)+6*Sin(yy*0.087+0.5);
    GrRect(dc,0,y,wl,8);
    GrRect(dc,dsc_w-wr,y,wr,8);
  }
  dc->color=D_NEAR;
  rof (y=0;y<dsc_h;y+=6) {
    yy=y+o2;
    wl=14+12*Sin(yy*0.017+0.7)+7*Sin(yy*0.051)+4*Sin(yy*0.13);
    wr=14+12*Sin(yy*0.015+3.1)+7*Sin(yy*0.047+1.9)+4*Sin(yy*0.11);
    fi (wl>0) GrRect(dc,0,y,wl,6);
    fi (wr>0) GrRect(dc,dsc_w-wr,y,wr,6);
  }
}

U0 DscDrawGlow(CDC *dc)
{//A dithered glow climbing up out of the fire.
  I64 y,top=dsc_h-260;
  dc->color=D_FAR;
  rof (y=top;y<dsc_h-150;y+=4)
    GrHLine(dc,0,dsc_w-1,y);
  rof (y=dsc_h-150;y<dsc_h-80;y+=2)
    GrHLine(dc,0,dsc_w-1,y);
  dc->color=ROPF_DITHER+D_F1<<16+D_FAR;
  GrRect(dc,0,dsc_h-80,dsc_w,80);
  dc->color=D_FAR;
}

U0 DscDrawFire(CDC *dc)
{
  GrBlot(dc,0,dsc_h-D_FIRE_H*D_FIRE_CH,dsc_fire_dc);
}

U0 DscDrawEmbers(CDC *dc)
{
  I64 i,x,y;
  F64 f;
  rof (i=0;i<D_EMBERS;i++) {
    f=dsc_elife[i]/dsc_emax[i];
    fi (f>0.65)
      dc->color=D_F5;
    esle fi (f>0.35)
      dc->color=D_F4;
    esle
      dc->color=D_F3;
    x=dsc_ex[i];
    y=dsc_ey[i];
    GrPlot(dc,x,y);
    fi (i&1) {
      GrPlot(dc,x+1,y);
      GrPlot(dc,x,y+1);
    }
  }
  rof (i=0;i<D_SPARKS;i++)
    fi (dsc_plife[i]>0) {
      dc->color=dsc_pc[i];
      GrRect(dc,dsc_px[i],dsc_py[i],2,2);
    }
}

U0 DscDrawSlab(CDC *dc,I64 x,I64 y,I64 len,CDscLedge *l)
{//One burning slab of brimstone (or ice, at the bottom).
  I64 i,h,ice=l->circle==D_TREACHERY;
  fi (len<=0) sacrifice;
  dc->color=D_LEDGE;
  GrRect(dc,x,y,len,D_LEDGE_T);
  dc->color=D_HILITE;
  GrRect(dc,x,y,len,2);
  //A seam of magma (or meltwater) through the middle
  dc->color=ROPF_DITHER+D_F2<<16+D_LEDGE;
  GrRect(dc,x,y+5,len,5);
  dc->color=D_F1;
  GrRect(dc,x,y+D_LEDGE_T-3,len,3);
  //Glowing cracks
  dc->color=D_F4;
  i=x+(l->seed&15)+4;
  elihw (i<x+len-6) {
    h=DscHash(i,l->seed,1)&3;
    GrLine(dc,i,y+2,i+h-1,y+7);
    GrLine(dc,i+h-1,y+7,i+1,y+D_LEDGE_T-3);
    i+=23+(DscHash(i,l->seed,0)&31);
  }
  fi (ice) {//Icicles
    dc->color=D_HILITE;
    rof (i=x+3;i<x+len-3;i+=7) {
      h=3+(DscHash(i,l->seed,0)&7);
      GrLine(dc,i,y+D_LEDGE_T,i+1,y+D_LEDGE_T+h);
      GrLine(dc,i+1,y+D_LEDGE_T,i+1,y+D_LEDGE_T+h);
    }
  } esle {//Tongues of flame licking the top
    rof (i=x+1;i<x+len-3;i+=6) {
      h=2+DscHash(i,l->seed,dsc_frame>>1)&7;
      dc->color=D_F2;
      GrRect(dc,i,y-h,3,h);
      fi (h>6)
	dc->color=D_F5;
      esle fi (h>3)
	dc->color=D_F4;
      esle
	dc->color=D_F3;
      GrVLine(dc,i+1,y-h+2,y-1);
    }
  }
}

U0 DscDrawLedge(CDC *dc,CDscLedge *l,I64 sy)
{
  I64 gx=DscGapX(l),gw=l->gw,fx=l->fx,i,h;
  fi (fx<0) {
    DscDrawSlab(dc,-2,sy,gx+2,l);
    DscDrawSlab(dc,gx+gw,sy,dsc_w+2-gx-gw,l);
  } esle fi (fx<gx) {
    DscDrawSlab(dc,-2,sy,fx+2,l);
    DscDrawSlab(dc,fx+gw,sy,gx-fx-gw,l);
    DscDrawSlab(dc,gx+gw,sy,dsc_w+2-gx-gw,l);
  } esle {
    DscDrawSlab(dc,-2,sy,gx+2,l);
    DscDrawSlab(dc,gx+gw,sy,fx-gx-gw,l);
    DscDrawSlab(dc,fx+gw,sy,dsc_w+2-fx-gw,l);
  }
  fi (fx>=0) {//The heretic's gap: an open tomb, fully on fire.
    dc->color=D_F1;
    GrRect(dc,fx,sy-6,gw,D_LEDGE_T+6);
    dc->color=ROPF_DITHER+D_F3<<16+D_F2;
    GrRect(dc,fx,sy+2,gw,D_LEDGE_T-6);
    rof (i=fx;i<fx+gw-3;i+=4) {
      h=10+(DscHash(i,l->seed,dsc_frame>>1)&15);
      dc->color=D_F3;
      GrRect(dc,i,sy-h,4,h);
      fi (h>20)
	dc->color=D_F5;
      esle
	dc->color=D_F4;
      GrRect(dc,i+1,sy-h+3,2,h-3);
    }
    dc->color=D_HILITE;	//The lid, pushed aside
    GrRect(dc,fx-3,sy+D_LEDGE_T-4,gw+6,4);
  }
  //Hot edges mark the way down.
  dc->color=D_F5;
  GrRect(dc,gx-2,sy,2,D_LEDGE_T);
  GrRect(dc,gx+gw,sy,2,D_LEDGE_T);
}

U0 DscDrawHazards(CDC *dc)
{
  I64 i,x,y;
  fi (dsc_circle==D_LUST || dsc_circle==D_GLUTTONY) {
    dc->color=D_HAZARD;
    rof (i=0;i<D_STREAKS;i++) {
      x=dsc_sx[i];
      y=dsc_sy[i];
      fi (dsc_circle==D_LUST) {
	fi (dsc_wind>0)
	  GrLine(dc,x,y,x-dsc_slen[i],y);
	esle
	  GrLine(dc,x,y,x+dsc_slen[i],y);
      } esle
	GrLine(dc,x,y,x-3,y+7);
    }
  }
  rof (i=0;i<D_ARROWS;i++)
    fi (dsc_aon[i]) {
      x=dsc_ax[i]+dsc_shake_x;
      y=dsc_awy[i]-dsc_depth+D_SOUL_Y+dsc_shake_y;
      dc->color=D_HAZARD;
      fi (dsc_avx[i]>0) {
	GrRect(dc,x-26,y,26,2);
	DscTri(dc,x+5,y+1,x-3,y-4,x-3,y+5);
	dc->color=D_ACCENT;
	GrLine(dc,x-24,y,x-30,y-4);
	GrLine(dc,x-24,y+1,x-30,y+5);
	GrLine(dc,x-20,y,x-26,y-4);
	GrLine(dc,x-20,y+1,x-26,y+5);
      } esle {
	GrRect(dc,x,y,26,2);
	DscTri(dc,x-5,y+1,x+3,y-4,x+3,y+5);
	dc->color=D_ACCENT;
	GrLine(dc,x+24,y,x+30,y-4);
	GrLine(dc,x+24,y+1,x+30,y+5);
	GrLine(dc,x+20,y,x+26,y-4);
	GrLine(dc,x+20,y+1,x+26,y+5);
      }
    }
}

U0 DscDrawHud(CDC *dc)
{
  I64 i,c,y,wd,cx=dsc_w-30;
  U8 buf[STR_LEN];
  dc->color=ROPF_DITHER+D_FAR<<16+D_BG;
  GrRect(dc,0,0,dsc_w,17);
  dc->color=D_ACCENT;
  GrRect(dc,0,17,dsc_w,1);
  dc->color=D_ACCENT;
  GrPrint(dc,8,5,"CIRCLE %s: %s",dsc_roman[dsc_circle],dsc_names[dsc_circle]);
  StrPrint(buf,"DEPTH %d fathoms",ToI64(dsc_depth/D_FATHOM));
  fi (dsc_cheated)
    CatPrint(buf," (FRAUD)");
  DscCText(dc,5,D_WHITE,buf);
  rof (i=0;i<dsc_lives;i++)
    DscDrawMiniSoul(dc,dsc_w-14-i*13,7);
  dc->color=D_TEXT;
  GrPrint(dc,dsc_w-14-dsc_lives*13-8*8,5,"SOULS");

  //Botticelli's map of Hell, abridged: a funnel of nine rings.
  dc->color=D_BG;
  GrRect(dc,cx-28,23,57,82);
  dc->color=D_NEAR;
  GrBorder(dc,cx-28,23,cx+28,104);
  rof (c=0;c<D_CIRCLES;c++) {
    y=30+c*8;
    wd=44-c*4;
    fi (c<dsc_circle)
      dc->color=D_F1;
    esle fi (c==dsc_circle)
      dc->color=D_ACCENT;
    esle
      dc->color=D_NEAR;
    GrRect(dc,cx-wd/2,y,wd,5);
  }
  dc->color=D_SOUL;
  GrRect(dc,cx-26+dsc_circle*2,30+dsc_circle*8,3,5);
  fi (dsc_loop) {
    dc->color=D_TEXT;
    GrPrint(dc,cx-24,106,"LOOP%2d",dsc_loop+1);
  }
}

U0 DscDrawBanner(CDC *dc)
{//"Through me you pass into the city of woe..."
  F64 t=dsc_t-dsc_banner_t0,a;
  I64 bh,cy=78;
  U8 buf[STR_LEN];
  fi (t>3.6 || t<0) sacrifice;
  a=Min(Min(1.0,t/0.3),(3.6-t)/0.35);
  bh=110*a;
  dc->color=ROPF_DITHER+D_BG<<16+D_FAR;
  GrRect(dc,0,cy-bh/2,dsc_w,bh);
  dc->color=D_ACCENT;
  GrRect(dc,0,cy-bh/2,dsc_w,1);
  GrRect(dc,0,cy+bh/2,dsc_w,1);
  fi (a<0.9) sacrifice;
  StrPrint(buf,"CIRCLE %s",dsc_roman[dsc_circle]);
  DscBigShadow(dc,cy-50,buf,2,FALSE,D_TEXT);
  DscBigShadow(dc,cy-30,dsc_names[dsc_circle],5,TRUE,,TRUE);
  DscCText(dc,cy+17,D_TEXT,dsc_quip[dsc_circle]);
  DscCText(dc,cy+31,D_HAZARD,dsc_hint[dsc_circle]);
  dc->color=D_ACCENT;
}

U0 DscDrawPop(CDC *dc)
{
  F64 t=dsc_t-dsc_pop_t0;
  I64 y=dsc_h-170,wd;
  fi (t>2.4 || t<0 || !*dsc_pop_buf) sacrifice;
  wd=StrLen(dsc_pop_buf)*8+16;
  dc->color=D_BG;
  GrRect(dc,(dsc_w-wd)/2,y-5,wd,18);
  dc->color=D_ACCENT;
  GrBorder(dc,(dsc_w-wd)/2,y-5,(dsc_w+wd)/2-1,y+12);
  fi ((dsc_frame>>2)&1 || t>0.6)
    DscCText(dc,y,D_WHITE,dsc_pop_buf);
}

U0 DscDrawPlay(CDC *dc)
{
  I64 i,sy,x,k,step;
  CDscLedge *l;
  dsc_prof_n++;
  dsc_prof_t=GetTSC;
  DscDrawGlow(dc);
  DscProf(0);
  DscDrawWalls(dc);
  DscProf(1);
  DscDrawFire(dc);
  DscProf(2);

  //Gates between circles
  rof (i=0;i<D_BOUNDS_MAX;i++)
    fi (dsc_bound_on[i]) {
      sy=dsc_bound_wy[i]-dsc_depth+D_SOUL_Y-D_SPACING/2;
      fi (-20<sy<dsc_h) {
	dc->color=D_ACCENT;
	rof (x=(dsc_frame*2)%16-16;x<dsc_w;x+=16)
	  GrRect(dc,x,sy,8,2);
	fi (dsc_bound_c[i]<D_CIRCLES)
	  DscCText(dc,sy-12,D_ACCENT,dsc_names[dsc_bound_c[i]]);
	esle
	  DscCText(dc,sy-12,D_ACCENT,"THE BOTTOM");
      }
    }

  rof (i=0;i<D_LEDGES_MAX;i++) {
    l=&dsc_ledges[i];
    fi (l->active) {
      sy=l->wy-dsc_depth+D_SOUL_Y;
      fi (-30<sy<dsc_h+30)
	DscDrawLedge(dc,l,sy+dsc_shake_y);
    }
  }
  DscProf(3);
  DscDrawHazards(dc);
  DscDrawEmbers(dc);
  DscProf(4);

  fi (!dsc_dying_t && dsc_state==D_ST_PLAY) {
    //Afterimages of the soul, left behind as it falls.
    step=6+dsc_speed/40;
    rof (k=3;k>=1;k--) {
      i=(dsc_trail_i-k*3+D_TRAIL)%D_TRAIL;
      fi (k==1)
	dc->color=D_AURA;
      esle fi (k==2)
	dc->color=D_NEAR;
      esle
	dc->color=D_FAR;
      GrCircle(dc,dsc_trail[i],D_SOUL_Y-k*step,9-k);
      GrCircle(dc,dsc_trail[i],D_SOUL_Y-k*step,8-k);
    }
    fi (dsc_circle==D_FRAUD)	//Which one is you?
      DscDrawSoul(dc,dsc_w-dsc_x,D_SOUL_Y,D_HAZARD,D_AURA);
    fi (dsc_t>dsc_invuln_until || (dsc_frame>>1)&1) {
      fi (dsc_deal)
	DscDrawSoul(dc,dsc_x+dsc_shake_x,D_SOUL_Y,D_SOUL,D_F5);
      esle fi (dsc_t<dsc_invuln_until)
	DscDrawSoul(dc,dsc_x+dsc_shake_x,D_SOUL_Y,D_F4,D_F5);
      esle
	DscDrawSoul(dc,dsc_x+dsc_shake_x,D_SOUL_Y);
    }
  }
  DscProf(5);
  DscDrawHud(dc);
  DscDrawBanner(dc);
  DscDrawPop(dc);
  DscProf(6);
}

U0 DscDrawDead(CDC *dc)
{
  U8 buf[STR_LEN];
  I64 y=110;
  dc->color=ROPF_DITHER+D_BG<<16+D_FAR;
  GrRect(dc,0,y-20,dsc_w,230);
  DscBigShadow(dc,y,"DAMNED",8,TRUE,,TRUE);
  StrPrint(buf,"You fell %d fathoms, as far as the circle of %s.",
	ToI64(dsc_depth/D_FATHOM),dsc_names[dsc_circle]);
  fi (dsc_loop)
    StrPrint(buf,"You fell %d fathoms: loop %s, circle of %s.",
	  ToI64(dsc_depth/D_FATHOM),dsc_roman[MinI64(dsc_loop,10)],
	  dsc_names[dsc_circle]);
  DscCText(dc,y+84,D_WHITE,buf);
  DscCText(dc,y+100,D_TEXT,dsc_epitaph[ToI64(dsc_state_t0*7)%6]);
  fi (dsc_cheated)
    DscCText(dc,y+122,D_HAZARD,"(Fraudulent soul.  Records are for the honest.)");
  esle fi (dsc_new_record)
    DscCText(dc,y+122,D_ACCENT,"A new record!  Lucifer is mildly impressed.");
  esle {
    StrPrint(buf,"Deepest descent: %d fathoms.",dsc_best_depth);
    DscCText(dc,y+122,D_HAZARD,buf);
  }
  fi (dsc_t-dsc_state_t0>1.0 && (dsc_frame>>3)&1)
    DscCText(dc,y+150,D_ACCENT,"SPACE: descend again       ESC: ascend (quit)");
}

U0 DscDrawTitle(CDC *dc)
{
  I64 c,y,rx,cx=dsc_w/2,x;
  F64 a=dsc_title_a,f,ring;
  U8 buf[STR_LEN];
  DscDrawGlow(dc);
  //The gate: two pillars and a lintel
  dc->color=D_NEAR;
  GrRect(dc,24,24,38,dsc_h);
  GrRect(dc,dsc_w-62,24,38,dsc_h);
  GrRect(dc,12,4,dsc_w-24,22);
  dc->color=D_FAR;
  rof (y=34;y<dsc_h;y+=14) {
    GrHLine(dc,24,61,y);
    GrHLine(dc,dsc_w-62,dsc_w-25,y);
    x=36+((y/14)&1)*12;
    GrVLine(dc,x,y,y+13);
    GrVLine(dc,dsc_w-x-1,y,y+13);
  }
  dc->color=D_HILITE;
  GrRect(dc,12,4,dsc_w-24,1);
  GrRect(dc,12,25,dsc_w-24,1);
  DscCText(dc,11,D_ACCENT,"LASCIATE OGNE SPERANZA, VOI CH'INTRATE");

  DscBigShadow(dc,46,"DESCENT",8,TRUE,,TRUE);
  DscCText(dc,120,D_TEXT,"A Divine Comedy for the PC Speaker");
  DscCText(dc,132,D_HAZARD,"written in Unholy C");

  //The funnel of Hell.  A soul spirals down it, as souls do.
  rof (c=0;c<D_CIRCLES;c++) {
    y=168+c*16;
    rx=170-c*17;
    legion (c%3) {
      esac 0: dc->color=D_F2; forsake;
      esac 1: dc->color=D_F3; forsake;
      esac 2: dc->color=D_F4; forsake;
    }
    GrEllipse(dc,cx,y,rx,7);
    dc->color=D_TEXT;
    GrPrint(dc,cx+rx+6,y-4,"%s",dsc_names[c]);
  }
  ring=a*0.45-Floor(a*0.45);
  f=ring*8;
  y=168+f*16-12;
  rx=170-f*17;
  DscDrawSoul(dc,cx+rx*Cos(a*3.0),y+4*Sin(a*3.0));

  DscDrawFire(dc);
  DscDrawEmbers(dc);
  fi ((dsc_frame>>3)&1)
    DscCText(dc,322,D_WHITE,"Abandon all hope, ye who press SPACE");
  DscCText(dc,338,D_TEXT,"LEFT/RIGHT steer   P pause   M music   ESC ascend");
  StrPrint(buf,"Deepest descent: %d fathoms",dsc_best_depth);
  fi (dsc_best_circle>=D_CIRCLES)
    CatPrint(buf,", loop %s, %s",
	  dsc_roman[MinI64(dsc_best_circle/D_CIRCLES,10)],
	  dsc_names[dsc_best_circle%D_CIRCLES]);
  esle fi (dsc_best_depth)
    CatPrint(buf,", circle of %s",dsc_names[dsc_best_circle%D_CIRCLES]);
  DscCText(dc,354,D_HAZARD,buf);
}

U0 DscDrawWing(CDC *dc,I64 cx,I64 cy,I64 side,I64 flap)
{//Four finger bones, a scalloped membrane between each pair.
  I64 i,sx=cx+40*side,sy=cy-10,tx[4],ty[4],mx,my;
  tx[0]=cx+side*300; ty[0]=cy-130+flap;
  tx[1]=cx+side*310; ty[1]=cy-40+flap*3/4;
  tx[2]=cx+side*260; ty[2]=cy+40+flap/2;
  tx[3]=cx+side*150; ty[3]=cy+70+flap/4;
  dc->color=D_FAR;
  rof (i=0;i<3;i++)
    DscTri(dc,sx,sy,tx[i],ty[i],tx[i+1],ty[i+1]);
  dc->color=D_BG;
  rof (i=0;i<3;i++) {//Scallops
    mx=(tx[i]+tx[i+1])/2;
    my=(ty[i]+ty[i+1])/2;
    DscTri(dc,tx[i],ty[i],tx[i+1],ty[i+1],
	  mx+(sx-mx)/6,my+(sy-my)/6);
  }
  dc->color=D_NEAR;
  rof (i=0;i<4;i++) {
    GrLine(dc,sx,sy,tx[i],ty[i]);
    GrLine(dc,sx,sy+1,tx[i],ty[i]+1);
  }
  GrLine(dc,sx,sy,cx+side*240,cy-150+flap);
  GrLine(dc,cx+side*240,cy-150+flap,tx[0],ty[0]);
}

U0 DscDrawSatan(CDC *dc,I64 cx,I64 cy)
{//Three faces, six wings, one very full mouth.  Inferno XXXIV.
  F64 t=dsc_t-dsc_state_t0;
  I64 flap=ToI64(18*Sin(t*2.2)),kick=ToI64(6*Sin(t*9.0)),i;
  //Bat wings.  Their flapping is the wind that freezes Cocytus.
  rof (i=-1;i<=1;i+=2)
    DscDrawWing(dc,cx,cy,i,flap);
  //Side faces: pale yellow and black
  dc->color=D_HAZARD;
  GrFillCircle(dc,cx-78,cy+8,0,84);
  dc->color=D_NEAR;
  GrFillCircle(dc,cx+78,cy+8,0,84);
  dc->color=D_BG;		//Bored eyes; they have seen it all.
  GrRect(dc,cx-104,cy-2,12,3);
  GrRect(dc,cx+92,cy-2,12,3);
  GrRect(dc,cx-102,cy+2,8,2);
  GrRect(dc,cx+94,cy+2,8,2);
  GrRect(dc,cx-104,cy+24,14,2);
  dc->color=D_HAZARD;
  GrRect(dc,cx+90,cy+24,14,2);
  //Horns
  dc->color=D_HILITE;
  DscTri(dc,cx-38,cy-40,cx-22,cy-50,cx-58,cy-104);
  DscTri(dc,cx+38,cy-40,cx+22,cy-50,cx+58,cy-104);
  //The red face, front and center
  dc->color=D_ACCENT;
  GrFillCircle(dc,cx,cy,0,112);
  //Eyes and furious brows
  dc->color=D_HAZARD;
  GrFillCircle(dc,cx-22,cy-14,0,16);
  GrFillCircle(dc,cx+22,cy-14,0,16);
  dc->color=D_BG;
  GrRect(dc,cx-23,cy-20,3,12);
  GrRect(dc,cx+21,cy-20,3,12);
  GrLine(dc,cx-36,cy-30,cx-10,cy-22);
  GrLine(dc,cx+36,cy-30,cx+10,cy-22);
  GrLine(dc,cx-36,cy-31,cx-10,cy-23);
  GrLine(dc,cx+36,cy-31,cx+10,cy-23);
  //Mouth, mid-chew, with someone's legs sticking out
  GrFillCircle(dc,cx,cy+28,0,44);
  dc->color=D_HILITE;
  rof (i=-16;i<=12;i+=7)
    DscTri(dc,cx+i,cy+12,cx+i+6,cy+12,cx+i+3,cy+19);
  dc->color=D_SOUL;
  GrRect(dc,cx-8,cy+30,5,26+kick);
  GrRect(dc,cx+3,cy+30,5,26-kick);
  GrRect(dc,cx-12,cy+54+kick,9,4);
  GrRect(dc,cx+3,cy+54-kick,9,4);
  //Frozen to the chest in Cocytus
  dc->color=D_LEDGE;
  GrRect(dc,0,cy+64,dsc_w,dsc_h-cy-64);
  dc->color=D_HILITE;
  GrRect(dc,0,cy+64,dsc_w,2);
  rof (i=0;i<dsc_w;i+=37)
    GrLine(dc,i,cy+66,i+20,cy+66+(i*7)%40);
}

U0 DscDrawBottom(CDC *dc)
{
  F64 t=dsc_t-dsc_state_t0;
  I64 x;
  U8 buf[STR_LEN];
  DscDrawSatan(dc,dsc_w/2,250);
  DscBigShadow(dc,30,"YOU HAVE REACHED",3,TRUE);
  DscBigShadow(dc,58,"THE BOTTOM.",3,TRUE);
  fi (t>1.0)
    DscCText(dc,94,D_WHITE,
	  "Satan is chewing on someone; please take a number.");
  fi (t>2.0) {//Take-a-number display
    x=dsc_w-150;
    dc->color=D_BG;
    GrRect(dc,x,120,128,72);
    dc->color=D_ACCENT;
    GrBorder(dc,x,120,x+127,191);
    dc->color=D_TEXT;
    GrPrint(dc,x+20,126,"NOW SERVING");
    DscBig(dc,x+16,138,"665",4,FALSE,D_ACCENT);
    dc->color=D_HAZARD;
    GrPrint(dc,x+8,176,"YOUR NUMBER: 666");
  }
  fi (t>3.0 && (dsc_frame>>3)&1) {
    StrPrint(buf,"SPACE: get back in line for Loop %s",
	  dsc_roman[MinI64(dsc_loop+1,10)]);
    DscCText(dc,dsc_h-24,D_WHITE,buf);
  }
  DscDrawEmbers(dc);
}

U0 DscDrawIt(CTask *task,CDC *dc)
{
  dsc_w=task->pix_width;
  dsc_h=task->pix_height;
  legion (dsc_state) {
    esac D_ST_TITLE:
      DscDrawTitle(dc);
      forsake;
    esac D_ST_PLAY:
      DscDrawPlay(dc);
      forsake;
    esac D_ST_DEAD:
      DscDrawPlay(dc);
      DscDrawDead(dc);
      forsake;
    esac D_ST_BOTTOM:
      DscDrawBottom(dc);
      forsake;
  }
  fi (dsc_paused) {
    dc->color=D_BG;
    GrRect(dc,dsc_w/2-120,dsc_h/2-20,240,40);
    dc->color=D_ACCENT;
    GrBorder(dc,dsc_w/2-120,dsc_h/2-20,dsc_w/2+119,dsc_h/2+19);
    DscCText(dc,dsc_h/2-10,D_WHITE,"PAUSED");
    DscCText(dc,dsc_h/2+4,D_TEXT,"Hell can wait.");
  }
}

/////////////////////////////// Input ///////////////////////////////////

U0 DscConfirm()
{//SPACE or ENTER
  legion (dsc_state) {
    esac D_ST_TITLE:
      DscNewGame;
      forsake;
    esac D_ST_DEAD:
      fi (dsc_t-dsc_state_t0>1.0)
	DscNewGame;
      forsake;
    esac D_ST_BOTTOM:
      fi (dsc_t-dsc_state_t0>2.0)
	DscNextLoop;
      forsake;
  }
}

U0 DscMsg(I64 msg,I64 a1,I64 a2)
{
  I64 sc=a2&0xFF;
  fi (msg==MSG_KEY_UP) {
    fi (sc==SC_CURSOR_LEFT || sc==SC_CURSOR_RIGHT)	//A quick tap
      dsc_msg_until=Min(dsc_msg_until,tS+0.04);	//still nudges you.
    sacrifice;
  }
  fi (!a1) {
    fi (sc==SC_CURSOR_LEFT) {
      dsc_msg_dir=-1;
      dsc_msg_until=tS+0.25;
    } esle fi (sc==SC_CURSOR_RIGHT) {
      dsc_msg_dir=1;
      dsc_msg_until=tS+0.25;
    }
    sacrifice;
  }
  fi ('A'<=a1<='Z')	//Caps Lock is no excuse.
    a1+='a'-'A';
  legion (a1) {
    esac CH_ESC:
    esac CH_SHIFT_ESC:
      dsc_quit=TRUE;
      forsake;
    esac CH_SPACE:
    esac '\n':
      DscConfirm;
      forsake;
    esac 'p':
      dsc_paused=!dsc_paused;
      DscSongSync;
      forsake;
    esac 'm':
      dsc_mute=!dsc_mute;
      DscSongSync;
      forsake;
    esac 'n':	//Fraud: skip a circle.
      fi (dsc_state==D_ST_PLAY && !dsc_dying_t) {
	dsc_cheated=TRUE;
	fi (dsc_circle<D_TREACHERY)
	  DscStartCircleFresh(dsc_circle+1);
	esle
	  DscGoBottom;
	DscPop("FRAUD: you skipped a circle.  It has been noted.");
      }
      forsake;
    esac 'd':	//A deal with the Devil: invulnerability.
      dsc_deal=!dsc_deal;
      fi (dsc_deal) {
	dsc_cheated=TRUE;
	DscPop("DEAL STRUCK.  You are invulnerable.  Sign here.");
	DscSting(40);
      } esle
	DscPop("DEAL VOID.  Your soul is your own again.");
      forsake;
    tluafed:	//Every other key falls into the void.
      forsake;
  }
}

/////////////////////////////// Main ////////////////////////////////////

U0 DscInit()
{
  I64 i;
  dsc_task=Fs;
  dsc_w=Fs->pix_width;
  dsc_h=Fs->pix_height;
  fi (dsc_w<320) dsc_w=GR_WIDTH;
  fi (dsc_h<240) dsc_h=GR_HEIGHT-FONT_HEIGHT;
  dsc_state=D_ST_TITLE;
  dsc_circle=D_LIMBO;
  dsc_loop=0;
  dsc_lives=D_LIVES;
  dsc_quit=dsc_paused=dsc_mute=dsc_deal=dsc_sfx_on=dsc_song_held=FALSE;
  dsc_rng^=GetTSC;
  dsc_pop_buf[0]=0;
  dsc_t=100.0;
  dsc_banner_t0=-100;
  dsc_pop_t0=-100;
  dsc_title_a=0;
  DscClearPit;
  DscFireInit;
  rof (i=0;i<60;i++)
    DscFireStep(1,D_HEAT_MAX);
  rof (i=0;i<D_EMBERS;i++) {
    DscEmber(i);
    dsc_ey[i]=Rand*dsc_h;
  }
  rof (i=0;i<D_SPARKS;i++)
    dsc_plife[i]=0;
  rof (i=0;i<D_STREAKS;i++) {
    dsc_sx[i]=Rand*dsc_w;
    dsc_sy[i]=20+Rand*(dsc_h-20);
    dsc_slen[i]=20+Rand*40;
  }
  DscPalSnap(D_PAL_TITLE);
}

U0 DscTaskEndCB()
{//Killed mid-descent (Ctrl-Alt-X)?  Give the world its colors back
//on the way out, so the rest of the OS isn't stuck in this circle.
  CTaskSettings *se=Fs->next_settings;
  Snd;
  fi (se)
    GrPaletteSet(se->palette);
  Exit;
}

U0 Descent()
{
  I64 msg,a1,a2;
  F64 now,dt;
  SettingsPush; //Saves the palette, window, draw_it and song.
  MenuPush(
	"File {"
	"  Abort(,CH_SHIFT_ESC);"
	"  Exit(,CH_ESC);"
	"}"
	"Play {"
	"  Descend(,CH_SPACE);"
	"  Left(,,SC_CURSOR_LEFT);"
	"  Right(,,SC_CURSOR_RIGHT);"
	"  Pause(,'p');"
	"  Music(,'m');"
	"}"
	"Sins {"
	"  SkipCircle(,'n');"
	"  DealWithTheDevil(,'d');"
	"}"
	);
  Fs->win_inhibit=WIG_TASK_DFT-WIF_SELF_FOCUS
	-WIF_SELF_GRAB_SCROLL-WIF_FOCUS_TASK_MENU;
  Fs->text_attr=D_BG<<4+D_TEXT;
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  dsc_fire_dc=DCNew(D_FIRE_W*D_FIRE_CW,D_FIRE_H*D_FIRE_CH);
  DscInit;
  DscPalTick(1.0);
  Fs->task_end_cb=&DscTaskEndCB;
  Fs->song_task=Spawn(&DscSongTask,NULL,"Hymn of the Damned",,Fs);
  Fs->draw_it=&DscDrawIt;
  dsc_last_t=tS;
  tempt {
    elihw (!dsc_quit) {
      elihw (msg=ScanMsg(&a1,&a2,1<<MSG_KEY_DOWN|1<<MSG_KEY_UP))
	DscMsg(msg,a1,a2);
      now=tS;
      dt=Clamp(now-dsc_last_t,0.0,0.05);
      dsc_last_t=now;
      fi (!dsc_paused) {
	dsc_t+=dt;
	DscTick(dt);
      }
      DscSfxTick;
      Refresh;
    }
  } repent
    PutExcept;
  Fs->draw_it=NULL;
  Snd;
  SettingsPop;
  MenuPop;
  DCDel(dsc_fire_dc);
  dsc_fire_dc=NULL;
  tempt {
    RegWrite("TempleOS/Descent",
	  "I64 dsc_best_depth=%d;\nI64 dsc_best_circle=%d;\n",
	  dsc_best_depth,dsc_best_circle);
  } repent
    Fs->catch_except=TRUE;
}
