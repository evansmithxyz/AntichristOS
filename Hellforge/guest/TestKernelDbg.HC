//WS2: show The Exorcist (forge.py run guest/TestKernelDbg.HC
//  --shots 11,13 --keys "15:G<semicolon><ret>").
//Enters the debugger on purpose; the host takes screenshots of the banner
//and then types "G;" to resume.  Exit 0 once resumed.
HfPrint("TKD entering debugger\n");
Dbg("Hellforge test: this task is possessed");
HfPrint("TKD resumed from the debugger\n");
HfShot("resumed");
hf_exit_code=0;
