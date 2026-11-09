"""Reproducible vector-style crossed swords. Standard library only; no runtime dependency."""
from pathlib import Path
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
SIZE = 64

def rotate(points, angle):
    c, s = math.cos(angle), math.sin(angle)
    return [(32+(x-32)*c-(y-32)*s, 32+(x-32)*s+(y-32)*c) for x,y in points]

outline = [(32,7),(37,15),(36,37),(43,37),(43,42),(36,42),
           (35,51),(37,53),(37,57),(27,57),(27,53),(29,51),
           (28,42),(21,42),(21,37),(28,37),(27,15)]
blade = [(32,10),(34.5,16),(34,37),(30,37),(29.5,16)]
guard = [(23,38.5),(41,38.5),(41,40.5),(23,40.5)]
grip = [(30,43),(34,43),(33,51),(31,51)]
pommel = [(29,54),(35,54),(35,55.5),(29,55.5)]
shapes = []
for angle in (-math.pi/4, math.pi/4):
    for polygon, color in ((outline,(12,14,20,255)), (blade,(255,255,255,255)),
                           (guard,(245,245,245,255)), (grip,(185,185,185,255)),
                           (pommel,(245,245,245,255))):
        shapes.append((rotate(polygon,angle),color))

def inside(x,y,poly):
    hit = False
    px,py = poly[-1]
    for qx,qy in poly:
        if (py>y)!=(qy>y) and x < (qx-px)*(y-py)/(qy-py)+px:
            hit = not hit
        px,py = qx,qy
    return hit

pixels = []
for y in range(SIZE):
    for x in range(SIZE):
        samples=[]
        for dy in (.125,.375,.625,.875):
            for dx in (.125,.375,.625,.875):
                xx,yy=x+dx,y+dy
                d=math.hypot(xx-32,yy-32)
                color=(0,0,0,0)
                if d<30: color=(12,14,20,220)
                if 28.5<d<30: color=(200,200,200,255)
                for poly,fill in shapes:
                    if inside(xx,yy,poly): color=fill
                samples.append(color)
        alpha=sum(c[3] for c in samples)/16
        rgb=[round(sum(c[i]*c[3] for c in samples)/(16*alpha)) if alpha else 0 for i in range(3)]
        pixels.append((*rgb,round(alpha)))

media=ROOT/'CallToArms/Media'
media.mkdir(exist_ok=True)
# Uncompressed 32-bit true-color TGA, bottom-left origin, eight alpha bits.
header=struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,SIZE,SIZE,32,8)
body=bytes(v for y in range(SIZE-1,-1,-1) for x in range(SIZE)
           for v in (pixels[y*SIZE+x][2],pixels[y*SIZE+x][1],pixels[y*SIZE+x][0],pixels[y*SIZE+x][3]))
(media/'CrossedSwords.tga').write_bytes(header+body)

def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)

# Development preview, enlarged and tinted to the test-pin color.
raw=b''.join(b'\0'+bytes(v for x in range(256) for v in
    (*[round(pixels[(y//4)*SIZE+x//4][i]*t) for i,t in enumerate((.8,.45,1))],
      pixels[(y//4)*SIZE+x//4][3])) for y in range(256))
preview=ROOT/'pin-preview.png'
preview.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,256,8,6,0,0,0))
                    +chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
assert len(header+body)==18+64*64*4
print(f'Built {media / "CrossedSwords.tga"} (64x64 RGBA, 16 KiB)')
