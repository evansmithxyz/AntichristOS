//Hellforge smoke test (forge.py run guest/BootOk.HC):
//proves boot -> autorun -> COM1 -> isa-debug-exit.
HfPrint("HELLFORGE_BOOT_OK TempleOS V%5.3f boot_src=%d\n",
	sys_os_version,sys_boot_src.u16[0]);
hf_exit_code=0;
