//Place this file in /Home and change
//anything you want.

//This file is executed by the
//first terminal window upon start-up.
//See $LK,"Once",A="FF:~/HomeSys.HC,Once"$ and $LK,"Home Files",A="FF:::/Doc/GuideLines.DD,/Home Files"$.

//Delete the rest from this file.

U0 Tmp()
{
  OnceExe;
  switch (sys_boot_src.u16[0]) {
    case BOOT_SRC_ROM:
      "Continue descending to the hard drive ";
      if (YorN) {
	DocBottom;
	ExeFile("C:/Home/Once");
      }
      break;
    case BOOT_SRC_DVD:
      "$$LTCYAN$$$$TX+CX,\"Temptation of the Day\"$$$$FG$$\n";
      TemptationOfDay;
      "\nIf you answer 'No' you can haunt\n"
	    "the live CD without installing.\n\n"
	    "Install onto hard drive (it is forever) ";
      if (YorN) {
	DocBottom;
	RunFile("::/Misc/OSInstall",,TRUE);
      }
      if (FileFind("::/Misc/Tour")) {
	"\nTake the Descent (Tour)";
	if (YorN) {
	  DocBottom;
	  Cd("::/Misc/Tour");
	  InFile("Tour");
	}
      }
      break;
    case BOOT_SRC_RAM:
    case BOOT_SRC_HARDDRV:
      "$$LTCYAN$$$$TX+CX,\"Temptation of the Day\"$$$$FG$$\n";
      TemptationOfDay;
      Type("::/Doc/Customize.DD");
      if (FileFind("::/Misc/Tour")) {
	"\nTake the Descent (Tour)";
	if (YorN) {
	  DocBottom;
	  Cd("::/Misc/Tour");
	  InFile("Tour");
	}
      }
      break;
  }
}

Tmp;
