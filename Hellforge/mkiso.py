#!/usr/bin/env python3
"""mkiso.py -- Hellforge: pure-Python TempleOS RedSea ISO (.ISO.C) writer.

Reproduces what TempleOS's own RedSeaISO() (::/Adam/Opt/Boot/DskISORedSea.HC)
does when called from ::/Misc/DoDistro.HC:

  DVD sector  0-15   system area (zero)
  DVD sector 16      ISO9660 primary volume descriptor  (CISOPriDesc layout)
  DVD sector 17      El Torito boot record (catalog ptr @0x47 = 20)
  DVD sector 18      supplementary descriptor, publisher "TempleOS RedSea"
  DVD sector 19      terminator
  DVD sector 20      El Torito boot catalog (no-emu, load_rba 21, sect_cnt 4)
  DVD sector 21      patched stage-1 loader (stage1.asm == BDVD_START..END)
  512-blk 88 (=22*4) RedSea drive: boot block (CRedSeaBoot), allocation bitmap,
                     root dir, then dirs/files allocated contiguously in
                     CopyTree() pre-order, exactly like RedSeaFmt/RedSeaMkDir/
                     RedSeaFileWrite would on a fresh BDT_ISO_FILE_WRITE drive.

File bytes are never re-encoded or compressed.  By default each file is stored
under a TempleOS-style "<name>.Z" name inside a CT_NONE CArcCompress header,
which ExpandBuf() returns verbatim (see dotz_tree(); --no-dotz stores the plain
bytes under the plain names instead).
Output is deterministic for a given tree + options.
"""
import argparse
import datetime as _dt
import fnmatch
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# ---- Constants from ::/Kernel/KernelA.HH -----------------------------------
BLK_SIZE_BITS = 9
BLK_SIZE = 1 << BLK_SIZE_BITS
DVD_BLK_SIZE = 4 * BLK_SIZE
DVD_BOOT_LOADER_SIZE = DVD_BLK_SIZE
CDIR_FILENAME_LEN = 38          # includes terminator
CDIR_SIZE = 64
MBR_PT_REDSEA = 0x88
INVALID_CLUS = -1

RS_ATTR_READ_ONLY = 0x01
RS_ATTR_HIDDEN = 0x02
RS_ATTR_SYSTEM = 0x04
RS_ATTR_VOL_ID = 0x08
RS_ATTR_DIR = 0x10
RS_ATTR_ARCHIVE = 0x20
RS_ATTR_DELETED = 0x100
RS_ATTR_RESIDENT = 0x200
RS_ATTR_COMPRESSED = 0x400
RS_ATTR_CONTIGUOUS = 0x800
RS_ATTR_FIXED = 0x1000

ISOT_BOOT_RECORD = 0
ISOT_PRI_VOL_DESC = 1
ISOT_SUPPLEMENTARY_DESC = 2
ISOT_TERMINATOR = 255

# RedSeaISO: bd->drv_offset=19<<2+(DVD_BLK_SIZE*2+DVD_BOOT_LOADER_SIZE)/BLK_SIZE
# ISOInit  : drv_offset = 19<<2 + (#boot records)*(2*DVD_BLK_SIZE+DVD_BLK_SIZE)/BLK_SIZE
DRV_OFFSET = (19 << 2) + (DVD_BLK_SIZE * 2 + DVD_BOOT_LOADER_SIZE) // BLK_SIZE  # 88

KERNEL_ISO_PATH = "0000Boot/0000Kernel.BIN.C"

# char_bmp_filename from ::/Kernel/StrA.HC (bit set == allowed in filenames)
_CHAR_BMP_FILENAME = [0x0000000, 0x03FF73FB, 0xEFFFFFFF, 0x6FFFFFFF,
                      0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
FILENAME_CHARS = frozenset(c for c in range(256)
                           if _CHAR_BMP_FILENAME[c >> 5] >> (c & 31) & 1)

DEFAULT_EXCLUDES = [".git", ".gitignore", ".gitattributes", ".github",
                    "Hellforge", ".claude", "*.swp", "Thumbs.db", "desktop.ini"]
# ::/Misc/DoDistro.HC adds these dirs (Home copied, empty here: "An empty /Home
# dir should be valid because it will get default files from the root dir").
DISTRO_DIRS = ["Home", "Tmp", "Tmp/ScrnShots"]

AUTORUN_ISO_PATH = "Hellforge/AutoRun.HC"
AUTORUN_INCLUDE = '#include "::/Hellforge/AutoRun.HC"'

DEFAULT_DATE = "2017-08-09 12:00:00"   # fixed for reproducible images


class IsoError(Exception):
    pass


# ---- CDate (::/Kernel/KDate.HC) --------------------------------------------
def _year_start_date(year):
    y1 = year - 1
    # HolyC integer division truncates toward zero; years here are positive.
    return year * 365 + y1 // 4 - y1 // 100 + y1 // 400 - y1 // 4000


_MON1 = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
_MON2 = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]


def cdate(dt):
    """datetime -> 64-bit CDate (time:U32 low, date:I32 high). Struct2Date()."""
    i1 = _year_start_date(dt.year)
    i2 = _year_start_date(dt.year + 1)
    i1 += (_MON1 if i2 - i1 == 365 else _MON2)[dt.month - 1]
    date = i1 + dt.day - 1
    sec10000 = dt.microsecond // 100
    total = sec10000 + 10000 * (dt.second + 60 * (dt.minute + 60 * dt.hour))
    time = (total << 21) // (15 * 15 * 3 * 625)
    return (time & 0xFFFFFFFF) | ((date & 0xFFFFFFFF) << 32)


def parse_date(s):
    if s in (None, ""):
        s = DEFAULT_DATE
    if s == "now":
        return _dt.datetime.now().replace(microsecond=0)
    if s.isdigit():
        return _dt.datetime.fromtimestamp(int(s), _dt.timezone.utc).replace(tzinfo=None)
    return _dt.datetime.fromisoformat(s)


# ---- Tree ------------------------------------------------------------------
class Node:
    __slots__ = ("name", "is_dir", "children", "data", "src", "clus", "size",
                 "attr", "parent")

    def __init__(self, name, is_dir, data=None, src=None):
        self.name = name
        self.is_dir = is_dir
        self.children = [] if is_dir else None
        self.data = data
        self.src = src
        self.clus = 0
        self.size = 0
        self.attr = 0
        self.parent = None

    def child(self, name):
        for c in self.children:
            if c.name == name:
                return c
        return None

    def add(self, node):
        node.parent = self
        self.children.append(node)
        return node

    def path(self):
        parts = []
        n = self
        while n.parent is not None:
            parts.append(n.name)
            n = n.parent
        return "/" + "/".join(reversed(parts))

    def walk(self):
        yield self
        if self.is_dir:
            for c in self.children:
                yield from c.walk()


def check_name(name, where):
    b = name.encode("latin-1", errors="strict") if isinstance(name, str) else name
    if b in (b".", b".."):
        raise IsoError(f"reserved name at {where}")
    if len(b) >= CDIR_FILENAME_LEN:
        raise IsoError(f"name too long for RedSea (max {CDIR_FILENAME_LEN-1}): {where}")
    bad = [chr(c) for c in b if c not in FILENAME_CHARS]
    if bad:
        raise IsoError(f"invalid RedSea filename chars {bad!r}: {where}")


def _excluded(rel, name, excludes):
    for pat in excludes:
        if fnmatch.fnmatchcase(rel, pat) or fnmatch.fnmatchcase(name, pat):
            return True
    return False


def scan_tree(src, excludes, skip_invalid=False, log=None):
    root = Node("", True)

    def rec(dirpath, node, relbase):
        try:
            entries = sorted(os.scandir(dirpath), key=lambda e: e.name)
        except OSError as e:
            raise IsoError(f"cannot read {dirpath}: {e}")
        for e in entries:
            rel = (relbase + "/" + e.name) if relbase else e.name
            if _excluded(rel, e.name, excludes):
                continue
            try:
                check_name(e.name, rel)
            except IsoError as err:
                if skip_invalid:
                    if log:
                        log(f"skip: {err}")
                    continue
                raise
            if e.is_dir(follow_symlinks=False):
                rec(e.path, node.add(Node(e.name, True)), rel)
            elif e.is_file(follow_symlinks=False):
                node.add(Node(e.name, False, src=e.path))
    rec(src, root, "")
    return root


def ensure_dir(root, iso_path):
    node = root
    for part in [p for p in iso_path.strip("/").split("/") if p]:
        check_name(part, iso_path)
        c = node.child(part)
        if c is None:
            c = node.add(Node(part, True))
        elif not c.is_dir:
            raise IsoError(f"{iso_path}: {part} is a file")
        node = c
    return node


def put_file(root, iso_path, data):
    iso_path = iso_path.strip("/")
    d, _, name = iso_path.rpartition("/")
    check_name(name, iso_path)
    parent = ensure_dir(root, d)
    c = parent.child(name)
    if c is not None:
        if c.is_dir:
            raise IsoError(f"{iso_path} is a dir")
        c.data, c.src = data, None
    else:
        parent.add(Node(name, False, data=data))


def get_file(root, iso_path):
    node = root
    for part in [p for p in iso_path.strip("/").split("/") if p]:
        node = node.child(part) if node.is_dir else None
        if node is None:
            return None
    return node


def add_file(root, iso_path, data, dotz=True):
    """--add: put data at iso_path.  The image shows .Z names, so an ISO path
    ending in .Z is accepted and means the same file as the plain name: plain
    bytes replace the repo file and are wrapped like it (by dotz_tree(), or
    right here with --no-dotz), and a CArcCompress blob is stored as given in
    place of the plain file.  Either way there is one entry, never a duplicate
    or raw bytes flagged compressed."""
    if iso_path.upper().endswith(".Z"):
        base = iso_path[:-2]
        if dotz and not is_arc(data):
            iso_path = base                       # dotz_tree() adds the .Z back
        else:
            if not is_arc(data):
                data = arc_wrap(data)
            old = get_file(root, base)
            if old is not None and not old.is_dir:
                old.parent.children.remove(old)
    put_file(root, iso_path, data)


def split_add(s):
    """'HOST:ISOPATH' -> (host, isopath).  Splits on the last ':' so a Windows
    drive letter in HOST works; refuses a spec without an ISO path."""
    i = s.rfind(":")
    host, isop = s[:i], s[i + 1:]
    if i < 0 or not host or not isop.strip("/") or \
            (len(host) == 1 and host.isalpha() and isop[:1] in ("/", "\\")):
        raise IsoError(f"--add expects HOST:ISOPATH, got {s!r}")
    return host, isop.replace("\\", "/")


def split_append(s):
    """'ISOPATH:HOST' -> (isopath, host)."""
    i = s.find(":")
    if i <= 0 or i == len(s) - 1:
        raise IsoError(f"--append expects ISOPATH:HOST, got {s!r}")
    return s[:i], s[i + 1:]


def file_bytes(node):
    if node.data is None:
        with open(node.src, "rb") as f:
            node.data = f.read()
    return node.data


def append_file(root, iso_path, text):
    """Append text (bytes) to an existing file, matching its line ending."""
    node = get_file(root, iso_path)
    if node is None or node.is_dir:
        raise IsoError(f"cannot append: {iso_path} not found")
    data = file_bytes(node)
    nl = b"\r\n" if b"\r\n" in data else b"\n"
    text = text.replace(b"\r\n", b"\n").replace(b"\n", nl)
    if data and not data.endswith(b"\n"):
        data += nl
    node.data = data + text
    node.src = None


# ---- Stage 1 ---------------------------------------------------------------
def find_nasm():
    for cand in (os.environ.get("NASM"), shutil.which("nasm"),
                 os.path.expanduser("~/AppData/Local/bin/NASM/nasm.exe"),
                 "/c/Users/evans/AppData/Local/bin/NASM/nasm"):
        if cand and os.path.exists(cand):
            return cand
    raise IsoError("nasm not found (set NASM=path)")


def _bytes_list(s):
    b = s.encode("latin-1")
    if not b:
        return "0"  # never empty; handled by caller
    return ",".join(str(c) for c in b)


def build_stage1(boot_msg="Loading TempleOS", not64_msg=None, workdir=None):
    """Assemble stage1.asm. Returns (bytes, {symbol: offset})."""
    nasm = find_nasm()
    tmp = tempfile.mkdtemp(prefix="hf_s1_", dir=workdir)
    try:
        out = os.path.join(tmp, "stage1.bin")
        mp = os.path.join(tmp, "stage1.map")
        # NASM's [map] directive stops its file name at the first blank (quotes
        # are taken literally), so NASM runs inside tmp and gets a bare name:
        # a TEMP path with a space in it must still work.
        cmd = [nasm, "-f", "bin", "-o", out, "-DMAPFILE=stage1.map"]
        if boot_msg:
            cmd.append("-DBOOT_MSG_BYTES=" + _bytes_list(boot_msg))
        if not64_msg:
            cmd.append("-DNOT64_MSG_BYTES=" + _bytes_list(not64_msg.replace("\\n", "\n").replace("\\r", "\r")))
        cmd.append(os.path.join(HERE, "stage1.asm"))
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=tmp)
        if r.returncode:
            raise IsoError("nasm failed:\n" + r.stdout + r.stderr)
        if not (os.path.isfile(out) and os.path.isfile(mp)):
            raise IsoError(f"nasm did not write {out} and {mp}:\n" + r.stdout + r.stderr)
        with open(out, "rb") as f:
            code = f.read()
        syms = {}
        with open(mp, "r", errors="replace") as f:
            for line in f:
                m = re.match(r"\s*([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)\s+(BDVD_\w+)\s*$", line)
                if m:
                    syms[m.group(3)] = int(m.group(1), 16)
        for need in ("BDVD_BLK_LO", "BDVD_BLK_CNT", "BDVD_SHIFT_BLKS", "BDVD_END"):
            if need not in syms:
                raise IsoError(f"stage1 map lacks {need}")
        if len(code) >= DVD_BOOT_LOADER_SIZE:
            raise IsoError("stage1 too big")
        return code, syms
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def patch_stage1(code, syms, kernel_clus, kernel_size):
    """RedSeaISO9660Stage1()."""
    buf = bytearray(DVD_BOOT_LOADER_SIZE)
    buf[:len(code)] = code
    blk_lo = kernel_clus >> 2
    blk_cnt = (kernel_size + DVD_BLK_SIZE - 1) >> (BLK_SIZE_BITS + 2)
    shift = kernel_clus & 3
    if shift:
        blk_cnt += 1
    struct.pack_into("<I", buf, syms["BDVD_BLK_LO"], blk_lo)
    struct.pack_into("<H", buf, syms["BDVD_BLK_CNT"], blk_cnt)
    struct.pack_into("<H", buf, syms["BDVD_SHIFT_BLKS"], shift)
    return bytes(buf), dict(blk_lo=blk_lo, blk_cnt=blk_cnt, shift=shift)


# ---- RedSea layout ---------------------------------------------------------
def _ceil(n, m):
    return (n + m - 1) // m * m


def dir_bytes(nentries):
    # RedSeaMkDir: size=CeilU64((entry_cnt+3)<<6,BLK_SIZE)
    return _ceil((nentries + 3) * CDIR_SIZE, BLK_SIZE)


def layout(root):
    """Assign sizes and compute the RedSea geometry like RedSeaISO()."""
    # RedSeaISOPass1 (in blocks).  Root counts the same as any dir.
    res = 0
    for n in root.walk():
        if n.is_dir:
            n.size = dir_bytes(len(n.children))
            res += n.size // BLK_SIZE
        else:
            n.size = len(file_bytes(n))
            res += _ceil(n.size, BLK_SIZE) // BLK_SIZE
    bitmap_blks = 1
    while True:
        b1 = bitmap_blks
        bitmap_blks = (res + bitmap_blks + (BLK_SIZE << 3) - 1) // (BLK_SIZE << 3)
        if bitmap_blks == b1:
            break
    max_blk = _ceil(DRV_OFFSET + 1 + bitmap_blks + res, 4) - 1
    while True:
        sects = max_blk + 1 - DRV_OFFSET
        bitmap_sects = (sects + (BLK_SIZE << 3) - 1) // (BLK_SIZE << 3)   # RedSeaFmt
        data_area = DRV_OFFSET + bitmap_sects
        # alloc #1 reserves data_area itself, then everything else follows.
        if data_area + 1 + res <= max_blk + 1:
            break
        max_blk += 4   # never happens in practice; keeps us safe
    nxt = [data_area]

    def alloc(cnt):
        c = nxt[0]
        nxt[0] += cnt
        return c

    alloc(1)                                   # "Alloc #1"
    root.clus = alloc(root.size // BLK_SIZE)   # init_root_dir_blks

    def place(d):                              # CopyTree2() pre-order
        for c in d.children:
            if c.is_dir:
                c.clus = alloc(c.size // BLK_SIZE)
                place(c)
            else:
                blks = _ceil(c.size, BLK_SIZE) // BLK_SIZE
                c.clus = alloc(blks) if blks else INVALID_CLUS
    place(root)
    return dict(res=res, max_blk=max_blk, sects=sects, bitmap_sects=bitmap_sects,
                data_area=data_area, used_end=nxt[0])


def _dirent(attr, name, clus, size, dt):
    nb = name if isinstance(name, bytes) else name.encode("latin-1")
    return struct.pack("<H38sqqQ", attr, nb.ljust(38, b"\0")[:38], clus, size, dt)


def _str_into(buf, off, s, n=None):
    b = s.encode("latin-1") if isinstance(s, str) else s
    if n is not None:
        b = b[:n]
    buf[off:off + len(b)] = b


def _pal16(buf, off, v):
    struct.pack_into("<H", buf, off, v)
    struct.pack_into(">H", buf, off + 2, v)


def _pal32(buf, off, v):
    struct.pack_into("<I", buf, off, v)
    struct.pack_into(">I", buf, off + 4, v)


def iso_descriptors(iso_size_dvd, root_clus, volume_id=None, catalog_id="TempleOS",
                    publisher="TempleOS RedSea"):
    """RedSeaISO9660(): returns bytes for DVD sectors 16..20."""
    # CISOPriDesc offsets (HolyC classes are packed):
    #  0 type, 1 id[5], 6 version, 7 pad[73], 80 vol_space_size(pal32),
    #  88 pad[32], 120 vol_set_size, 124 vol_seq_num, 128 log_block_size,
    #  132 pad[20], 152 root_dir_record(CISODirEntry: pad2, loc pal32 @154),
    #  186 pad[128], 314 publisher_id[128], 442 pad[435],
    #  877 file_structure_version
    pri = bytearray(DVD_BLK_SIZE)
    pri[0] = ISOT_PRI_VOL_DESC
    _str_into(pri, 1, "CD001")
    pri[6] = 1
    _pal16(pri, 120, 1)
    _pal16(pri, 124, 1)
    _pal16(pri, 128, DVD_BLK_SIZE)
    _pal32(pri, 80, iso_size_dvd)
    _pal32(pri, 154, root_clus & 0xFFFFFFFF)
    pri[877] = 1
    _str_into(pri, 314, publisher, 127)
    if volume_id:
        # Not written by TempleOS; standard ISO9660 volume identifier slot
        # (offset 40, 32 a-chars, space padded) lies inside TempleOS's pad[73].
        _str_into(pri, 40, volume_id.upper()[:32].ljust(32))
    sup = bytearray(pri)
    sup[0] = ISOT_SUPPLEMENTARY_DESC

    boot = bytearray(DVD_BLK_SIZE)
    boot[0] = ISOT_BOOT_RECORD
    _str_into(boot, 1, "CD001")
    boot[6] = 1
    _str_into(boot, 7, "EL TORITO SPECIFICATION")
    struct.pack_into("<I", boot, 0x47, 20)

    term = bytearray(DVD_BLK_SIZE)
    term[0] = ISOT_TERMINATOR
    _str_into(term, 1, "CD001")
    term[6] = 1

    # CElTorito
    et = bytearray(DVD_BLK_SIZE)
    struct.pack_into("<H", et, 0, 1)
    _str_into(et, 4, catalog_id, 24)
    struct.pack_into("<H", et, 30, 0xAA55)
    s = sum(struct.unpack_from("<16H", et, 0)) & 0xFFFF
    struct.pack_into("<H", et, 28, (-s) & 0xFFFF)
    et[32] = 0x88          # bootable
    et[33] = 0             # no emulation
    struct.pack_into("<H", et, 34, 0)    # load_seg 0 -> 07C0
    et[36] = 0             # sys_type
    et[37] = 0
    struct.pack_into("<H", et, 38, 4)    # sect_cnt
    struct.pack_into("<I", et, 40, 21)   # load_rba
    return bytes(pri), bytes(boot), bytes(sup), bytes(term), bytes(et)


def build_image(root, stage1, syms, dt, volume_id=None, catalog_id="TempleOS",
                unique_id=None):
    geo = layout(root)
    total_blks = geo["max_blk"] + 1
    img = bytearray(total_blks * BLK_SIZE)
    dtv = cdate(dt)

    def wblk(blk, data):
        off = blk * BLK_SIZE
        img[off:off + len(data)] = data

    # Boot block (RedSeaFmt)
    if unique_id is None:
        unique_id = 0
    bb = bytearray(BLK_SIZE)
    bb[3] = MBR_PT_REDSEA
    struct.pack_into("<qqqqQ", bb, 8, DRV_OFFSET, geo["sects"], root.clus,
                     geo["bitmap_sects"], unique_id & 0xFFFFFFFFFFFFFFFF)
    struct.pack_into("<H", bb, 510, 0xAA55)
    wblk(DRV_OFFSET, bb)

    # Bitmap: bit i <-> block data_area+i ; mark [data_area, used_end)
    bm = bytearray(geo["bitmap_sects"] * BLK_SIZE)
    used = geo["used_end"] - geo["data_area"]
    for i in range(used // 8):
        bm[i] = 0xFF
    for i in range(used & ~7, used):
        bm[i >> 3] |= 1 << (i & 7)
    wblk(DRV_OFFSET + 1, bm)
    # NB: block data_area == last bitmap block; alloc #1 owns it, so the
    # bitmap write above is what lands there (exactly as on TempleOS).

    # Dirs and files
    for n in root.walk():
        if n.is_dir:
            parent = n.parent if n.parent is not None else n
            ents = [_dirent(RS_ATTR_DIR | RS_ATTR_CONTIGUOUS,
                            "." if n is root else n.name, n.clus, n.size, dtv),
                    _dirent(RS_ATTR_DIR | RS_ATTR_CONTIGUOUS, "..", parent.clus, 0, dtv)]
            for c in n.children:
                if c.is_dir:
                    attr = RS_ATTR_DIR | RS_ATTR_CONTIGUOUS
                else:
                    attr = RS_ATTR_CONTIGUOUS
                    if c.name.upper().endswith(".Z"):
                        attr |= RS_ATTR_COMPRESSED
                c.attr = attr
                ents.append(_dirent(attr, c.name, c.clus, c.size, dtv))
            data = b"".join(ents)
            assert len(data) + CDIR_SIZE <= n.size
            wblk(n.clus, data)
        else:
            if n.size:
                wblk(n.clus, file_bytes(n))

    # Kernel + stage 1
    kern = get_file(root, KERNEL_ISO_PATH)
    if kern is None:
        raise IsoError(f"/{KERNEL_ISO_PATH} missing from tree")
    kdata = file_bytes(kern)
    if kdata[4:8] != b"TOSB":
        raise IsoError("kernel lacks TOSB signature")
    s1, patch = patch_stage1(stage1, syms, kern.clus, kern.size)
    wblk(21 * 4, s1)
    pri, boot, sup, term, et = iso_descriptors(total_blks // 4, root.clus,
                                               volume_id, catalog_id)
    wblk(16 * 4, pri)
    wblk(17 * 4, boot)
    wblk(18 * 4, sup)
    wblk(19 * 4, term)
    wblk(20 * 4, et)
    geo.update(kernel_clus=kern.clus, kernel_size=kern.size, stage1=patch)
    return bytes(img), geo


# ---- DolDoc bin-tail workaround ---------------------------------------------
# The archive this repo was imported from had every 0x05 byte (CH_CURSOR)
# stripped from DolDoc-format files -- including from their binary tails
# (sprites, .MAP debug info).  That shifts the CDocBin headers, so DocLoad()
# loses bins and DocBinsValidate() RawPrint(3000)s "Bin Not Found" for every
# reference: ~1000 x 3s at boot (Kernel.MAP+Compiler.MAP alone ~860).
# A stripped byte inside a bin also leaves that bin itself corrupt: its
# declared size runs past the end of the file (DocLoad() then copies whatever
# follows the file buffer), or its sprite elements no longer parse, and
# Sprite3() walks out of sprite_elem_base_sizes[] into the heap (GP faults,
# endless WinMgr loops, QEMU-WHPX "failed to decode instruction").
# --patch-broken-bins rewrites such tails in the IMAGE ONLY (never the repo).
_BI_RE = re.compile(rb"BI=(\d+)")
# DolDoc-format files.  (.GR is not one: GRWrite() stores a raw CDC, DCSave().)
DOLDOC_EXT_RE = re.compile(r"\.(HC|HH|DD|IN|PRJ|TXT|MAP)(\.Z)?$", re.I)
MAP_EXT_RE = re.compile(r"\.MAP(\.Z)?$", re.I)
_BI_STRIP_RE = re.compile(rb",BI=(\d+)")


def _bin_hdr_ok(t, s):
    num, flags, size, use = struct.unpack_from("<4I", t, s)
    return 0 < num < 0x100000 and flags < 0x10000 and use < 0x10000 \
        and s + 16 + size <= len(t)


def doc_bin_check(data):
    """Parse a DolDoc binary tail like DocLoad() does.

    Returns (text_len, intact_bins[(off,num,size)], missing_refs, overrun) or
    None if the file has no NUL (no tail).  intact_bins stops at the first
    implausible header, which includes a bin whose declared size runs past the
    end of the file.  overrun is how far DocLoad() reads past the end of the
    file (negative: that many leftover bytes it ignores); a sound tail has 0."""
    i = data.find(b"\0")
    if i < 0:
        return None
    t = data[i + 1:]
    refs = set(int(x) for x in _BI_RE.findall(data[:i]))
    s, intact, nums, broken = 0, [], [], False
    while s <= len(t) - 16:            # DocLoad: while (src<=src2+size-16)
        num, flags, size, use = struct.unpack_from("<4I", t, s)
        nums.append(num)
        if not broken and _bin_hdr_ok(t, s):
            intact.append((s, num, size))
        else:
            broken = True
        s += 16 + size
    return i, intact, sorted(refs - set(nums)), s - len(t)


# Sprites (the only kind of bin in a DolDoc other than a .MAP's CDbgInfo; see
# ::/Doc/DolDocOverview.DD $IB).  sprite_elem_base_sizes[] in
# ::/Adam/Gr/SpriteNew.HC, i.e. the packed CSprite* classes of ::/Adam/Gr/Gr.HH.
SPT_BASE_SIZES = (1, 2, 3, 5, 17, 1, 1, 9, 9, 13, 17, 5, 17, 25, 13, 25, 29,
                  5, 5, 5, 5, 9, 9, 17, 9, 21, 17, 9, 9, 9)
SPT_TYPES_NUM = len(SPT_BASE_SIZES)      # 30
SPG_TYPE_MASK = 0x7F


def sprite_ok(d):
    """True if d is well-formed sprite data: SpriteElemSize() steps through
    elements of known types (< SPT_TYPES_NUM, no negative counts) and lands on
    SPT_END at exactly the last byte, as the sprite editor saves them (a
    sprite bin's size is SpriteSize()).  Anything else is damaged data."""
    off, n = 0, len(d)
    while off < n:
        t = d[off] & SPG_TYPE_MASK
        if t == 0:                                   # SPT_END
            return off == n - 1
        if t >= SPT_TYPES_NUM:
            return False
        size = SPT_BASE_SIZES[t]
        if off + size > n:
            return False
        cnt = ()
        if t == 11:                                  # SPT_POLYLINE: num CD2I32
            cnt = struct.unpack_from("<i", d, off + 1)
            extra = cnt[0] * 8
        elif 17 <= t <= 20:                          # SPT_BSPLINE*: num CD3I32
            cnt = struct.unpack_from("<i", d, off + 1)
            extra = cnt[0] * 12
        elif t == 9:                                 # SPT_POLYPT: 3 bits each
            cnt = struct.unpack_from("<i", d, off + 1)
            extra = (cnt[0] * 3 + 7) >> 3
        elif t == 23:                                # SPT_BITMAP: w x h bytes
            cnt = struct.unpack_from("<ii", d, off + 9)
            extra = ((cnt[0] + 7) & ~7) * cnt[1]
        elif t == 24:                                # SPT_MESH
            cnt = struct.unpack_from("<ii", d, off + 1)
            extra = cnt[0] * 12 + cnt[1] * 16
        elif t == 25:                                # SPT_SHIFTABLE_MESH
            cnt = struct.unpack_from("<ii", d, off + 13)
            extra = cnt[0] * 12 + cnt[1] * 16
        elif t >= 27:                                # SPT_TEXT*: NUL-ended
            j = d.find(b"\0", off + size)
            if j < 0:
                return False
            extra = j + 1 - (off + size)
        else:
            extra = 0
        if any(c < 0 for c in cnt):
            return False
        off += size + extra
    return False


def doc_bin_problems(data, map_file=False):
    """None if data has no bin tail or a sound one, else
    dict(missing=[bin nums referenced but lost], overrun=N,
    bad_sprites=[bin nums whose data is not a well-formed sprite]).
    map_file: the bins are CDbgInfo (.MAP), not sprites.
    This is the rule both doccheck and --patch-broken-bins use."""
    r = doc_bin_check(data)
    if r is None:
        return None
    i, intact, missing, overrun = r
    bad = []
    if not map_file:
        t = data[i + 1:]
        bad = sorted({num for off, num, size in intact
                      if not sprite_ok(t[off + 16:off + 16 + size])})
    if missing or overrun or bad:
        return dict(missing=missing, overrun=overrun, bad_sprites=bad)
    return None


def patch_bin_tail(data, strip_refs=False):
    """Rebuild a broken tail: keep the intact leading bins that are sound; for
    every other referenced bin either add an empty sprite (one SPT_END byte),
    or with strip_refs (used for .MAP files, whose bins are CDbgInfo) drop the
    ',BI=n' from the text so MapFileLoad() just has no line info for that
    symbol.  Returns new bytes, or None if the file is fine."""
    prob = doc_bin_problems(data, map_file=strip_refs)
    if prob is None:
        return None
    i, intact, missing, overrun = doc_bin_check(data)
    bad = set(prob["bad_sprites"])
    text, t = data[:i], data[i + 1:]
    out, have = [], set()
    for off, num, size in intact:
        if num in have:
            break
        have.add(num)
        if num not in bad:
            out.append(t[off:off + 16 + size])
    have -= bad
    lost = sorted(set(int(x) for x in _BI_RE.findall(text)) - have)
    if strip_refs:
        lost_set = set(lost)
        text = _BI_STRIP_RE.sub(
            lambda m: b"" if int(m.group(1)) in lost_set else m.group(0), text)
    else:
        for num in lost:
            out.append(struct.pack("<4I", num, 0, 1, 1) + b"\0")
    return text + b"\0" + b"".join(out)


# .GR pictures are not DolDoc: GRWrite() stores a raw DCSave() (CDC.start..end,
# the palette if DCF_PALETTE, then the body, normally CompressBuf()ed).  The
# same 0x05 stripping hit Demo/Games/Stadium/StadiumBG.GR: its LZW body is 20
# bytes short and GRRead() of it hangs.
GR_EXT_RE = re.compile(r"\.GR(\.Z)?$", re.I)
GR_HDR = struct.Struct("<q6i")   # cdt, x0, y0, width, width_internal, height, flags
DCF_COMPRESSED, DCF_PALETTE = 1, 2
GR_PALETTE_SIZE = 16 * 6         # COLORS_NUM CBGR48s


def gr_problem(data):
    """None if data is a whole DCSave() picture, else what is wrong with it."""
    if len(data) < GR_HDR.size:
        return "shorter than a CDC header"
    w, wi, h, flags = GR_HDR.unpack_from(data)[3:]
    if not (0 < w <= wi and 0 < h and wi * h <= 1 << 26):
        return f"implausible header ({w}x{h}, width_internal {wi})"
    off = GR_HDR.size + (GR_PALETTE_SIZE if flags & DCF_PALETTE else 0)
    if flags & DCF_COMPRESSED:
        if len(data) < off + ARC_HDR.size:
            return "body header cut off"
        csize, esize, ctype = ARC_HDR.unpack_from(data, off)
        if esize != wi * h or not CT_NONE <= ctype <= CT_8_BIT or csize < ARC_HDR.size:
            return "bad body header"
        need = off + csize
    else:
        need = off + wi * h
    if need > len(data):
        return f"picture data {need - len(data)} bytes short"
    if need < len(data):
        return f"{len(data) - need} stray bytes after the picture"
    return None


def patch_gr(data):
    """A damaged picture -> one of the same size and palette with a blank
    (colour 0) CT_NONE body, so GRRead() returns; None if data is fine or its
    header is unusable."""
    if gr_problem(data) is None or len(data) < GR_HDR.size:
        return None
    hdr = list(GR_HDR.unpack_from(data))
    w, wi, h, flags = hdr[3:]
    if not (0 < w <= wi and 0 < h and wi * h <= 1 << 26):
        return None
    pal = b""
    if flags & DCF_PALETTE:
        pal = data[GR_HDR.size:GR_HDR.size + GR_PALETTE_SIZE]
        if len(pal) != GR_PALETTE_SIZE:
            pal, flags = b"", flags & ~DCF_PALETTE
    hdr[6] = flags | DCF_COMPRESSED
    return GR_HDR.pack(*hdr) + pal + arc_wrap(bytes(wi * h))


# ---- .Z names, as on a real TempleOS disk --------------------------------------
# The original distro stored nearly every file TempleOS-compressed under a
# "<name>.Z" name (e.g. ::/Doc/StandBy.DD.Z, ~/PersonalMenu.DD.Z,
# ::/Misc/Bible.TXT.Z are looked up by exact name).  The repo holds the expanded
# files, so dotz_tree() puts the .Z back.  It wraps each file in a CT_NONE
# CArcCompress header (I64 compressed_size, I64 expanded_size, U8 type=1),
# which ExpandBuf() returns verbatim, and mkiso marks it RS_ATTR_COMPRESSED like
# FileWrite() would.  These stay unwrapped:
#   * /0000Boot/* and *.C: contiguous files read raw (the CD boot kernel)
#   * ACDefs.DATA: AutoComplete opens it with FOpen() for raw block access
#     (ACWords.DATA must be .Z: ACInit FileFind()s ACWords.DATA.Z by exact
#     name, and without it the dictionary fill-ins are off)
#   * a name that would grow past 37 chars (it is stored plain, with a note)
CT_NONE = 1
CT_8_BIT = 3
ARC_HDR = struct.Struct("<qqB")
DOTZ_KEEP_RE = re.compile(r"(\.Z|\.C)$|^ACDefs\.DATA$", re.I)


def arc_wrap(data):
    """data -> a CT_NONE CArcCompress blob that ExpandBuf() returns as is."""
    return ARC_HDR.pack(ARC_HDR.size + len(data), len(data), CT_NONE) + data


def is_arc(data):
    """True if data is a whole CArcCompress blob, as every .Z file must be:
    FileRead() ExpandBuf()s anything RS_ATTR_COMPRESSED.  CompressBuf() sets
    compressed_size to the whole blob, header included."""
    if len(data) < ARC_HDR.size:
        return False
    csize, esize, ctype = ARC_HDR.unpack_from(data)
    return csize == len(data) and CT_NONE <= ctype <= CT_8_BIT and esize >= 0


def dotz_tree(root, log=None):
    n_wrapped = 0
    for n in list(root.walk()):
        if n.is_dir or DOTZ_KEEP_RE.search(n.name) or n.path().upper().startswith("/0000BOOT/"):
            continue
        if len((n.name + ".Z").encode("latin-1")) >= CDIR_FILENAME_LEN:
            if log:
                log(f"mkiso: {n.path()} stays unwrapped: {n.name}.Z would exceed "
                    f"RedSea's {CDIR_FILENAME_LEN - 1} chars")
            continue
        n.data = arc_wrap(file_bytes(n))
        n.src = None
        n.name += ".Z"
        n_wrapped += 1
    for n in root.walk():
        if n.is_dir:
            n.children.sort(key=lambda c: c.name)
    return n_wrapped


def check_tree(root):
    """Refuse an image the guest would misread: two entries with one name
    (RedSea lookups take the first and silently ignore the other) or a .Z
    file that is not CArcCompress data (FileRead() throws 'Compress')."""
    for n in root.walk():
        if n.is_dir:
            seen = set()
            for c in n.children:                # RedSea names: StrCmp()
                if c.name in seen:
                    raise IsoError(f"duplicate entry {c.path()}")
                seen.add(c.name)
        elif n.name.upper().endswith(".Z") and not is_arc(file_bytes(n)):
            raise IsoError(f"{n.path()}: a .Z file must hold CArcCompress data")


# ---- Identity strings taken from the OS's own sources -------------------------
_HC_ESC = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'", "0": "\0"}
_HC_STR = r'"((?:\\.|[^"\\])*)"'


def _holyc_unescape(lit):
    """Decode a HolyC string literal body as it sits in a DolDoc source file."""
    lit = lit.replace("$$", "$")
    out, i = [], 0
    while i < len(lit):
        if lit[i] == "\\" and i + 1 < len(lit):
            out.append(_HC_ESC.get(lit[i + 1], lit[i + 1]))
            i += 2
        else:
            out.append(lit[i])
            i += 1
    return "".join(out)


def _source_text(src, *parts):
    try:
        with open(os.path.join(src, *parts), "rb") as f:
            return f.read().split(b"\0")[0].decode("latin-1")
    except OSError:
        return None


def source_identity(src):
    """The stage-1 messages (Adam/Opt/Boot/BootDVD.HC) and El Torito catalog id
    (Adam/Opt/Boot/DskISORedSea.HC) of the tree being imaged, so the image says
    whatever the OS sources say.  Returns a dict with whichever of boot_msg,
    not64_msg and catalog_id could be found."""
    res = {}
    t = _source_text(src, "Adam", "Opt", "Boot", "BootDVD.HC")
    if t:
        named = dict(re.findall(r"^\s*(BDVD_\w+):\s*DU8\s+" + _HC_STR + r"\s*,\s*0\s*;", t, re.M))
        msgs = re.findall(r"DU8\s+" + _HC_STR + r"\s*,\s*0\s*;", t)
        boot = named.get("BDVD_TEMPLEOS_MSG", msgs[0] if msgs else None)
        n64 = named.get("BDVD_NOT64_MSG", msgs[1] if len(msgs) > 1 else None)
        if boot is not None:
            res["boot_msg"] = _holyc_unescape(boot)
        if n64 is not None:
            res["not64_msg"] = _holyc_unescape(n64)
    t = _source_text(src, "Adam", "Opt", "Boot", "DskISORedSea.HC")
    if t:
        m = re.search(r"StrCpy\(&et->w\[2\],\s*" + _HC_STR + r"\)", t)
        if m:
            res["catalog_id"] = _holyc_unescape(m.group(1))[:24]
    return res


# ---- High-level -------------------------------------------------------------
def make_iso(src, out, boot_msg=None, volume_id=None, excludes=None,
             inject_autorun=None, add=(), append=(), mkdirs=None, date=None,
             catalog_id=None, not64_msg=None, skip_invalid=False,
             manifest=None, patch_bins=False, dotz=True, log=print):
    """Build the ISO. Returns geometry dict.  boot_msg, not64_msg and catalog_id
    default to what the tree's own BootDVD.HC / DskISORedSea.HC say."""
    ident = source_identity(src)
    if boot_msg is None:
        boot_msg = ident.get("boot_msg", "Loading TempleOS")
    if not64_msg is None:
        not64_msg = ident.get("not64_msg")
    if catalog_id is None:
        catalog_id = ident.get("catalog_id", "TempleOS")
    excl = list(DEFAULT_EXCLUDES) + list(excludes or [])
    root = scan_tree(src, excl, skip_invalid=skip_invalid, log=log)
    patched = []
    if patch_bins:
        for n in root.walk():
            nd = None
            if n.is_dir:
                continue
            if DOLDOC_EXT_RE.search(n.name):
                nd = patch_bin_tail(file_bytes(n),
                                    strip_refs=bool(MAP_EXT_RE.search(n.name)))
            elif GR_EXT_RE.search(n.name):
                nd = patch_gr(file_bytes(n))
            if nd is not None:
                n.data, n.src = nd, None
                patched.append(n.path())
        if patched:
            log(f"mkiso: patched {len(patched)} damaged DolDoc bin tails / .GR "
                f"pictures (image only)")
    for d in (DISTRO_DIRS if mkdirs is None else mkdirs):
        ensure_dir(root, d)
    for host, isop in add:
        with open(host, "rb") as f:
            add_file(root, isop, f.read(), dotz)
    for isop, host in append:
        if dotz and isop.upper().endswith(".Z") and get_file(root, isop) is None:
            isop = isop[:-2]           # the repo file, before dotz_tree() names it .Z
        with open(host, "rb") as f:
            append_file(root, isop, f.read())
    if inject_autorun:
        with open(inject_autorun, "rb") as f:
            put_file(root, AUTORUN_ISO_PATH, f.read())
        append_file(root, "StartOS.HC",
                    b"\n//Hellforge autorun (injected, not in repo)\n"
                    + AUTORUN_INCLUDE.encode() + b"\n")
    if dotz:
        log(f"mkiso: stored {dotz_tree(root, log)} files under .Z names (CT_NONE)")
    check_tree(root)
    stage1, syms = build_stage1(boot_msg, not64_msg)
    dt = parse_date(date)
    # deterministic "unique_id": hash of tree paths+sizes+date
    h = hashlib.sha1()
    for n in root.walk():
        h.update(n.path().encode("latin-1"))
        if not n.is_dir:
            h.update(struct.pack("<Q", len(file_bytes(n))))
    h.update(str(dt).encode())
    uid = struct.unpack("<Q", h.digest()[:8])[0]
    img, geo = build_image(root, stage1, syms, dt, volume_id, catalog_id, uid)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    tmp = out + ".tmp"
    with open(tmp, "wb") as f:
        f.write(img)
    os.replace(tmp, out)
    nfiles = sum(1 for n in root.walk() if not n.is_dir)
    ndirs = sum(1 for n in root.walk() if n.is_dir)
    geo.update(files=nfiles, dirs=ndirs, bytes=len(img), out=out, patched=patched,
               sha1=hashlib.sha1(img).hexdigest(), crc32=zlib.crc32(img))
    if manifest:
        with open(manifest, "w", newline="\n") as f:
            f.write(f"# Hellforge ISO manifest for {out}\n")
            for k in ("max_blk", "sects", "bitmap_sects", "data_area", "used_end",
                      "kernel_clus", "kernel_size", "stage1", "sha1"):
                f.write(f"# {k} = {geo[k]}\n")
            f.write("# clus(512-blk)  size  attr  path\n")
            for n in root.walk():
                f.write(f"{n.clus:8d} {n.size:9d} {n.attr or 0x810:04X} {n.path()}"
                        f"{'/' if n.is_dir and n.parent else ''}\n")
    return geo


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build a TempleOS RedSea ISO (.ISO.C)")
    ap.add_argument("--src", default=REPO, help="source tree (default: repo root)")
    ap.add_argument("--out", default=os.path.join(HERE, "out", "TempleOS.ISO.C"))
    ap.add_argument("--boot-msg", default=None,
                    help="stage1 boot message (default: from the tree's BootDVD.HC)")
    ap.add_argument("--not64-msg", default=None,
                    help="stage1 'requires 64-bit' message (\\n\\r escapes ok)")
    ap.add_argument("--volume-id", default=None,
                    help="ISO9660 volume id (not set by TempleOS; optional)")
    ap.add_argument("--catalog-id", default=None,
                    help="El Torito validation entry id string (24 chars; default: "
                         "from the tree's DskISORedSea.HC)")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    ap.add_argument("--inject-autorun", metavar="FILE",
                    help=f"place FILE at /{AUTORUN_ISO_PATH} and #include it at end of StartOS.HC")
    ap.add_argument("--add", action="append", default=[], metavar="HOST:ISOPATH",
                    help="add/replace a file in the image")
    ap.add_argument("--append", action="append", default=[], metavar="ISOPATH:HOST",
                    help="append HOST file contents to ISOPATH")
    ap.add_argument("--mkdir", action="append", default=None, metavar="ISODIR",
                    help="extra empty dirs (default: Home, Tmp, Tmp/ScrnShots like DoDistro)")
    ap.add_argument("--date", default=None,
                    help=f"timestamp for all entries: ISO date, unix secs, or 'now' (default {DEFAULT_DATE})")
    ap.add_argument("--skip-invalid", action="store_true",
                    help="skip names RedSea cannot store instead of failing")
    ap.add_argument("--manifest", default=None, help="write a block map listing")
    ap.add_argument("--no-dotz", dest="dotz", action="store_false",
                    help="store files under their plain names instead of TempleOS-style .Z")
    ap.add_argument("--patch-broken-bins", action="store_true",
                    help="in the image only, replace lost, truncated or malformed "
                         "DolDoc sprite bins with an empty sprite and damaged .GR "
                         "pictures with blank ones (see README)")
    a = ap.parse_args(argv)
    try:
        geo = make_iso(a.src, a.out, boot_msg=a.boot_msg, volume_id=a.volume_id,
                       excludes=a.exclude, inject_autorun=a.inject_autorun,
                       add=[split_add(s) for s in a.add],
                       append=[split_append(s) for s in a.append],
                       mkdirs=a.mkdir, date=a.date, catalog_id=a.catalog_id,
                       not64_msg=a.not64_msg, skip_invalid=a.skip_invalid,
                       manifest=a.manifest, patch_bins=a.patch_broken_bins,
                       dotz=a.dotz)
    except IsoError as e:
        print("mkiso: error:", e, file=sys.stderr)
        return 1
    except OSError as e:
        print(f"mkiso: error: {e}", file=sys.stderr)
        return 1
    print(f"mkiso: wrote {geo['out']} ({geo['bytes']} bytes, {geo['files']} files, "
          f"{geo['dirs']} dirs) kernel clus={geo['kernel_clus']} stage1={geo['stage1']} "
          f"sha1={geo['sha1']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
