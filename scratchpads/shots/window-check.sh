#!/bin/bash
# ============================================================================
#  window-check.sh -- does an INTERACTIVE dev mode actually SHOW its window?
#
#      scratchpads/shots/window-check.sh mapdebug /tmp/out.png [:79]
#
#  The window is created with $SCREENHIDE and stays hidden until _SCREENSHOW,
#  which normal play only reaches at the bottom of dungeon.bas -- long after a
#  dev mode has run and SYSTEMed. A mode that forgets to call it draws and
#  polls keys perfectly into a window nobody can see: no error, no output, the
#  process just sits there. mapdebug, dataedit and packbrowse all shipped that
#  way, and nothing in the gate could tell, because every headless *shot* mode
#  writes its PNG correctly without a window ever being visible.
#
#  So this photographs the X ROOT of a PRIVATE Xvfb and reports what percentage
#  of it is lit. A hidden window is ~0%.
#
#  Two rules it follows on purpose:
#    * its own Xvfb on its own display -- never the user's session
#    * kill by exact PID, never `pkill -f`, which matches the killer's own argv
#      and SIGTERMs the shell running it (exit 144)
# ============================================================================
mode="$1"; out="$2"; dpy="${3:-:79}"
Xvfb $dpy -screen 0 1280x1024x24 >/dev/null 2>&1 &
XPID=$!
sleep 2
DISPLAY=$dpy setsid ./dungeon.run $mode >/dev/null 2>&1 &
APID=$!
sleep 7
DISPLAY=$dpy xwd -root -silent > /tmp/w.xwd 2>/dev/null
kill -TERM -$APID 2>/dev/null; kill $APID 2>/dev/null
sleep 1
kill $XPID 2>/dev/null
python3 - "$out" <<'PY'
import struct, zlib, sys
d=open('/tmp/w.xwd','rb').read()
hsz=struct.unpack('>I',d[:4])[0]
w,h=struct.unpack('>II',d[16:24]); bpl=struct.unpack('>I',d[48:52])[0]
ncol=struct.unpack('>I',d[76:80])[0]
off=hsz+ncol*12
rows=[]; nonblack=0
for y in range(h):
    r=d[off+y*bpl: off+y*bpl+w*4]
    o=bytearray(b'\x00')
    for x in range(0,w*4,4):
        b,g,rr=r[x],r[x+1],r[x+2]
        if b>12 or g>12 or rr>12: nonblack+=1
        o+=bytes((rr,g,b))
    rows.append(bytes(o))
raw=b''.join(rows)
def ch(t,dta):
    c=t+dta; return struct.pack('>I',len(dta))+c+struct.pack('>I',zlib.crc32(c))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw,6))+ch(b'IEND',b''))
print("  %-14s %d x %d, %.1f%% of pixels lit" % (sys.argv[1].split('/')[-1], w, h, 100.0*nonblack/(w*h)))
PY
