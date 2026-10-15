#!/usr/bin/env python3
"""qemu.py -- Hellforge headless QEMU harness for TempleOS/AntichristOS ISOs.

  * -machine pc (i440fx + PIIX IDE: CD at secondary master 0x170, which
    TempleOS's BootDVDProbeAll() finds by itself -- no port prompt)
  * -display none, HMP monitor on a localhost TCP port (screendump/sendkey)
  * -serial file:...  (COM1 -> host file)
  * isa-debug-exit at 0xF4: guest OutU8(0xF4,c) -> QEMU exits with (c<<1)|1
  * accel: whpx first (if requested/auto), tcg fallback
  * hard wall-clock timeout, process always killed
"""
import argparse
import os
import shutil
import socket
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")


def find_qemu():
    for cand in (os.environ.get("QEMU"), shutil.which("qemu-system-x86_64"),
                 r"C:\Program Files\qemu\qemu-system-x86_64.exe",
                 "/c/Program Files/qemu/qemu-system-x86_64.exe"):
        if cand and os.path.exists(cand):
            return cand
    raise RuntimeError("qemu-system-x86_64 not found (set QEMU=path)")


def _win_kill_on_close(proc):
    """Windows: put QEMU in a job object that dies with this Python process,
    so a killed harness can never leave an orphaned VM behind."""
    if os.name != "nt":
        return None
    try:
        import ctypes
        from ctypes import wintypes

        class BASIC(ctypes.Structure):
            _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64),
                        ("PerJobUserTimeLimit", ctypes.c_int64),
                        ("LimitFlags", wintypes.DWORD),
                        ("MinimumWorkingSetSize", ctypes.c_size_t),
                        ("MaximumWorkingSetSize", ctypes.c_size_t),
                        ("ActiveProcessLimit", wintypes.DWORD),
                        ("Affinity", ctypes.c_size_t),
                        ("PriorityClass", wintypes.DWORD),
                        ("SchedulingClass", wintypes.DWORD)]

        class IOC(ctypes.Structure):
            _fields_ = [(n, ctypes.c_uint64) for n in ("a", "b", "c", "d", "e", "f")]

        class EXT(ctypes.Structure):
            _fields_ = [("Basic", BASIC), ("Io", IOC),
                        ("ProcessMemoryLimit", ctypes.c_size_t),
                        ("JobMemoryLimit", ctypes.c_size_t),
                        ("PeakProcessMemoryUsed", ctypes.c_size_t),
                        ("PeakJobMemoryUsed", ctypes.c_size_t)]
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.CreateJobObjectW.restype = wintypes.HANDLE
        k32.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                ctypes.c_void_p, wintypes.DWORD]
        k32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
        job = k32.CreateJobObjectW(None, None)
        info = EXT()
        info.Basic.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        k32.SetInformationJobObject(job, 9, ctypes.byref(info), ctypes.sizeof(info))
        k32.AssignProcessToJobObject(job, int(proc._handle))
        return job
    except Exception:  # noqa -- best effort
        return None


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


# HMP sendkey names for ASCII
_KEYNAMES = {" ": "spc", "\n": "ret", "\t": "tab", "-": "minus", "=": "equal",
             "[": "bracket_left", "]": "bracket_right", ";": "semicolon",
             "'": "apostrophe", "`": "grave_accent", "\\": "backslash",
             ",": "comma", ".": "dot", "/": "slash"}
_SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
            "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal",
            "{": "bracket_left", "}": "bracket_right", ":": "semicolon",
            '"': "apostrophe", "~": "grave_accent", "|": "backslash",
            "<": "comma", ">": "dot", "?": "slash"}


def char_to_key(ch):
    if ch.isalpha():
        return ("shift-" + ch.lower()) if ch.isupper() else ch
    if ch.isdigit():
        return ch
    if ch in _KEYNAMES:
        return _KEYNAMES[ch]
    if ch in _SHIFTED:
        return "shift-" + _SHIFTED[ch]
    raise ValueError(f"no key for {ch!r}")


class Qemu:
    def __init__(self, iso, mem=1024, accel="auto", smp=1, serial=None,
                 extra=(), log=print, name="hellforge", debugcon=None, workdir=None):
        self.workdir = workdir or OUT
        self.iso = os.path.abspath(iso)
        self.mem = mem
        self.accel_req = accel
        self.smp = smp
        self.serial = os.path.abspath(serial) if serial else None
        self.debugcon = debugcon
        self.extra = list(extra)
        self.log = log
        self.name = name
        self.proc = None
        self.mon = None
        self.accel = None
        self.t0 = None
        self.stderr_path = None
        self._lock = threading.Lock()

    # ---- process ------------------------------------------------------
    def _cmd(self, accel, port):
        cmd = [find_qemu(), "-name", self.name,
               "-machine", "pc", "-accel", accel,
               "-m", str(self.mem), "-smp", str(self.smp),
               "-cdrom", self.iso, "-boot", "d",
               "-display", "none", "-vga", "std",
               "-rtc", "base=localtime",
               "-monitor", f"tcp:127.0.0.1:{port},server=on,wait=off",
               "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04",
               "-nic", "none",      # TempleOS has no network stack
               "-no-reboot"]
        if self.serial:
            cmd += ["-serial", "file:" + self.serial.replace("\\", "/")]
        else:
            cmd += ["-serial", "null"]
        if self.debugcon:
            cmd += ["-debugcon", "file:" + self.debugcon.replace("\\", "/"),
                    "-global", "isa-debugcon.iobase=0xe9"]
        return cmd + self.extra

    def _launch(self, accel):
        port = free_port()
        if self.serial and os.path.exists(self.serial):
            os.remove(self.serial)
        os.makedirs(self.workdir, exist_ok=True)
        self.stderr_path = os.path.join(self.workdir, f"{self.name}.qemu-stderr.txt")
        errf = open(self.stderr_path, "wb")
        cmd = self._cmd(accel, port)
        self.cmdline = cmd
        flags = 0
        if os.name == "nt":
            flags = subprocess.CREATE_NEW_PROCESS_GROUP
        self.proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL,
                                     stdout=errf, stderr=errf, creationflags=flags)
        self._job = _win_kill_on_close(self.proc)
        errf.close()
        self.t0 = time.monotonic()
        # connect monitor
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if self.proc.poll() is not None:
                return False
            try:
                s = socket.create_connection(("127.0.0.1", port), timeout=1)
                s.settimeout(10)
                self.mon = s
                self._read_prompt()
                return True
            except OSError:
                time.sleep(0.1)
        return False

    def start(self):
        order = {"auto": ["whpx", "tcg"], "whpx": ["whpx"], "tcg": ["tcg"]}.get(
            self.accel_req, [self.accel_req])
        for acc in order:
            ok = self._launch(acc)
            if ok:
                # WHPX can fail a bit later (e.g. hypervisor platform missing)
                time.sleep(1.0)
                if self.proc.poll() is None:
                    self.accel = acc
                    self.log(f"qemu: started pid={self.proc.pid} accel={acc}")
                    return self
            err = self.stderr_text()
            self.log(f"qemu: accel {acc} failed: {err.strip()[:300]}")
            self.kill()
        raise RuntimeError("could not start QEMU with any accelerator")

    def stderr_text(self):
        try:
            with open(self.stderr_path, "rb") as f:
                return f.read().decode("latin-1")
        except OSError:
            return ""

    def elapsed(self):
        return time.monotonic() - self.t0 if self.t0 else 0.0

    def alive(self):
        return self.proc is not None and self.proc.poll() is None

    def kill(self):
        try:
            if self.mon:
                try:
                    self.mon.sendall(b"quit\n")
                except OSError:
                    pass
                self.mon.close()
        finally:
            self.mon = None
        if self.proc and self.proc.poll() is None:
            try:
                self.proc.wait(3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(5)

    def wait(self, timeout):
        try:
            return self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            return None

    @staticmethod
    def guest_code(rc):
        """isa-debug-exit: QEMU status = (code<<1)|1."""
        if rc is not None and rc & 1:
            return rc >> 1
        return None

    # ---- monitor ------------------------------------------------------
    def _read_prompt(self):
        buf = b""
        while not buf.endswith(b"(qemu) "):
            chunk = self.mon.recv(65536)
            if not chunk:
                raise OSError("monitor closed")
            buf += chunk
        return buf.decode("latin-1")

    def hmp(self, cmd):
        with self._lock:
            if not self.mon:
                raise OSError("no monitor")
            self.mon.sendall(cmd.encode() + b"\n")
            out = self._read_prompt()
        # strip echo/escapes
        return out

    def screendump(self, png_path):
        from PIL import Image
        ppm = png_path + ".ppm"
        self.hmp(f"screendump {ppm.replace(chr(92), '/')}")
        for _ in range(50):
            if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
                break
            time.sleep(0.05)
        im = Image.open(ppm)
        im.load()
        im.save(png_path)
        os.remove(ppm)
        return png_path

    def sendkey(self, key, hold_ms=None):
        self.hmp(f"sendkey {key}" + (f" {hold_ms}" if hold_ms else ""))

    def type_text(self, text, delay=0.05):
        for ch in text:
            self.sendkey(char_to_key(ch))
            time.sleep(delay)


def parse_keys(spec):
    """'SECS:keys;SECS:keys' where keys is text, or <name> for raw sendkey names."""
    out = []
    for part in [p for p in spec.split(";") if p]:
        t, _, keys = part.partition(":")
        out.append((float(t), keys))
    return out


def send_keyspec(q, keys):
    i = 0
    while i < len(keys):
        if keys[i] == "<":
            j = keys.index(">", i)
            q.sendkey(keys[i + 1:j])
            i = j + 1
        else:
            q.sendkey(char_to_key(keys[i]))
            i += 1
        time.sleep(0.05)


def run(iso, timeout=180, shots=(), shot_every=None, shot_prefix="shot",
        serial=None, keys=(), accel="auto", mem=1024, smp=1, stream=None,
        stop_on=None, log=print, name="hellforge", keep_running=False,
        shot_dir=None, expect=(), anchor=None):
    """Boot ISO; returns dict(rc, guest_code, accel, elapsed, shots, serial,
    timed_out, stalled).

    stream(chunk) gets every new serial chunk; it may return an iterable of
    screenshot names, which are taken at once as <shot_dir>/<prefix>_<name>.png
    (the guest side of this is HfShot() in guest/Serial.HC).
    expect: [(secs, needle_bytes, label)] -- if needle has not appeared on
    serial after secs, stop early as a timeout with stalled=label (e.g. a
    boot-time compile error that never reaches the autorun).
    anchor: (needle_bytes, calib_secs) -- shots/keys scheduled at t >= calib_secs
    are held until needle appears on serial and then fire at
    t - calib_secs + <time needle appeared>, so scripts written for one boot
    time keep working when boot gets slower or faster.
    """
    sdir = shot_dir or OUT
    os.makedirs(sdir, exist_ok=True)
    q = Qemu(iso, mem=mem, accel=accel, smp=smp, serial=serial, log=log, name=name,
             workdir=sdir)
    q.start()
    pending_shots = sorted(shots)
    pending_keys = sorted(keys)
    next_every = shot_every
    taken = []
    rc = None
    timed_out = False
    stalled = None
    serial_pos = 0
    serial_buf = b""
    stop_hit = None
    anchor_needle, anchor_cal = anchor if anchor else (None, None)
    anchor_at = [None]

    def due(t, el):
        if anchor_needle is None or t < anchor_cal:
            return el >= t
        return anchor_at[0] is not None and el >= t - anchor_cal + anchor_at[0]

    def shot(tag, el):
        p = os.path.join(sdir, f"{shot_prefix}_{tag}.png")
        try:
            q.screendump(p)
            taken.append(p)
            log(f"qemu: [{el:6.1f}s] screenshot {p}")
        except Exception as e:  # noqa
            log(f"qemu: screendump failed: {e}")

    try:
        while True:
            el = q.elapsed()
            if not q.alive():
                rc = q.proc.returncode
                break
            if el >= timeout:
                timed_out = True
                break
            while pending_shots and due(pending_shots[0], el):
                t = pending_shots.pop(0)
                shot(f"{t:06.1f}s", el)
            if next_every and el >= next_every:
                shot(f"{el:06.1f}s", el)
                next_every += shot_every
            while pending_keys and due(pending_keys[0][0], el):
                _, k = pending_keys.pop(0)
                log(f"qemu: [{el:6.1f}s] sendkeys {k!r}")
                try:
                    send_keyspec(q, k)
                except Exception as e:  # noqa
                    log(f"qemu: sendkey failed: {e}")
            if serial and os.path.exists(serial):
                with open(serial, "rb") as f:
                    f.seek(serial_pos)
                    chunk = f.read()
                serial_pos += len(chunk)
                if chunk:
                    serial_buf += chunk
                    if anchor_needle and anchor_at[0] is None and anchor_needle in serial_buf:
                        anchor_at[0] = q.elapsed()
                        log(f"qemu: [{anchor_at[0]:6.1f}s] anchor {anchor_needle.decode()!r} "
                            f"(scripted times >= {anchor_cal:g}s shift by "
                            f"{anchor_at[0] - anchor_cal:+.1f}s)")
                    if stream:
                        for nm in (stream(chunk) or ()):
                            shot(nm, q.elapsed())
                    if stop_on and stop_on.encode() in serial_buf and not keep_running:
                        stop_hit = q.elapsed()
                        log(f"qemu: [{stop_hit:6.1f}s] saw {stop_on!r} on serial")
                        break
            for secs, needle, label in expect:
                if el >= secs and needle not in serial_buf:
                    stalled = label
                    break
            if stalled:
                timed_out = True
                log(f"qemu: [{el:6.1f}s] stalled: {stalled}")
                break
            time.sleep(0.1)
    finally:
        el = q.elapsed()
        if timed_out and q.alive():
            p = os.path.join(sdir, f"{shot_prefix}_timeout.png")
            try:
                q.screendump(p)
                taken.append(p)
                log(f"qemu: timeout screenshot {p}")
            except Exception as e:  # noqa
                log(f"qemu: timeout screendump failed: {e}")
        if q.alive():
            q.kill()
        if rc is None and q.proc is not None and not timed_out and stop_hit is None:
            rc = q.proc.returncode
    # drain serial
    if serial and os.path.exists(serial):
        with open(serial, "rb") as f:
            f.seek(serial_pos)
            chunk = f.read()
        if chunk and stream:
            stream(chunk)  # QEMU is gone: shot requests can't be honoured now
        serial_buf += chunk
    return dict(rc=rc, guest_code=Qemu.guest_code(rc), accel=q.accel, elapsed=el,
                shots=taken, serial=serial_buf, timed_out=timed_out, stalled=stalled,
                cmdline=q.cmdline, stderr=q.stderr_text())


def main(argv=None):
    ap = argparse.ArgumentParser(description="Boot an ISO headless in QEMU")
    ap.add_argument("iso")
    ap.add_argument("--timeout", type=float, default=180)
    ap.add_argument("--shots", default="", help="comma list of seconds for screenshots")
    ap.add_argument("--every", type=float, default=None, help="screenshot interval secs")
    ap.add_argument("--prefix", default="shot")
    ap.add_argument("--serial", default=os.path.join(OUT, "serial.txt"))
    ap.add_argument("--keys", default="", help="'SECS:text;SECS:<ret>' sendkey script")
    ap.add_argument("--accel", default="auto", choices=["auto", "whpx", "tcg"])
    ap.add_argument("--mem", type=int, default=1024)
    ap.add_argument("--smp", type=int, default=1)
    ap.add_argument("--stop-on", default=None, help="stop when this text appears on serial")
    a = ap.parse_args(argv)
    shots = [float(s) for s in a.shots.split(",") if s]

    def echo(b):  # must return None: a returned iterable means "take screenshots"
        sys.stdout.write(b.decode("latin-1"))
        sys.stdout.flush()

    r = run(a.iso, timeout=a.timeout, shots=shots, shot_every=a.every,
            shot_prefix=a.prefix, serial=a.serial, keys=parse_keys(a.keys),
            accel=a.accel, mem=a.mem, smp=a.smp, stop_on=a.stop_on, stream=echo)
    print(f"\nqemu: rc={r['rc']} guest_code={r['guest_code']} accel={r['accel']} "
          f"elapsed={r['elapsed']:.1f}s timed_out={r['timed_out']}")
    return 0 if not r["timed_out"] else 124


if __name__ == "__main__":
    sys.exit(main())
