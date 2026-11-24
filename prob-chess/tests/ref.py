# Gerador de lances ingenuo e totalmente independente (mailbox 8x8), so p/ validar.
import sys
WH, BL = 'w', 'b'
def color(pc): return WH if pc.isupper() else BL
N,S,E,W = 8,-8,1,-1
DIRS = {'N':[15,17,-15,-17,10,6,-10,-6],'B':[9,7,-9,-7],'R':[8,-8,1,-1],
        'Q':[9,7,-9,-7,8,-8,1,-1],'K':[9,7,-9,-7,8,-8,1,-1]}
def fr(sq): return sq>>3, sq&7
def ok(r,f): return 0<=r<8 and 0<=f<8
KN=[(1,2),(2,1),(2,-1),(1,-2),(-1,-2),(-2,-1),(-2,1),(-1,2)]
KG=[(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)]
SL={'B':[(1,1),(1,-1),(-1,1),(-1,-1)],'R':[(1,0),(-1,0),(0,1),(0,-1)]}
SL['Q']=SL['B']+SL['R']

class P:
    __slots__=('b','stm','cr','ep','hm','fm')
    def __init__(s,fen):
        parts=fen.split()
        s.b=[None]*64
        r=7;f=0
        for ch in parts[0]:
            if ch=='/': r-=1; f=0
            elif ch.isdigit(): f+=int(ch)
            else: s.b[r*8+f]=ch; f+=1
        s.stm=parts[1]; s.cr=set(parts[2]) if parts[2]!='-' else set()
        s.ep=None if parts[3]=='-' else (int(parts[3][1])-1)*8+(ord(parts[3][0])-97)
        s.hm=int(parts[4]); s.fm=int(parts[5])
    def copy(s):
        q=P.__new__(P); q.b=s.b[:]; q.stm=s.stm; q.cr=set(s.cr); q.ep=s.ep; q.hm=s.hm; q.fm=s.fm; return q

def attacked(p, sq, by):
    r0,f0=fr(sq)
    # peoes
    d = -1 if by==WH else 1
    for df in (-1,1):
        r,f=r0+d,f0+df
        if ok(r,f):
            pc=p.b[r*8+f]
            if pc and color(pc)==by and pc.upper()=='P': return True
    for dr,df in KN:
        r,f=r0+dr,f0+df
        if ok(r,f):
            pc=p.b[r*8+f]
            if pc and color(pc)==by and pc.upper()=='N': return True
    for dr,df in KG:
        r,f=r0+dr,f0+df
        if ok(r,f):
            pc=p.b[r*8+f]
            if pc and color(pc)==by and pc.upper()=='K': return True
    for dr,df in SL['B']:
        r,f=r0+dr,f0+df
        while ok(r,f):
            pc=p.b[r*8+f]
            if pc:
                if color(pc)==by and pc.upper() in ('B','Q'): return True
                break
            r+=dr; f+=df
    for dr,df in SL['R']:
        r,f=r0+dr,f0+df
        while ok(r,f):
            pc=p.b[r*8+f]
            if pc:
                if color(pc)==by and pc.upper() in ('R','Q'): return True
                break
            r+=dr; f+=df
    return False

def ksq(p,c):
    k='K' if c==WH else 'k'
    return p.b.index(k) if k in p.b else None

def gen(p):
    out=[]
    us=p.stm; them=BL if us==WH else WH
    for sq in range(64):
        pc=p.b[sq]
        if not pc or color(pc)!=us: continue
        r0,f0=fr(sq); t=pc.upper()
        if t=='P':
            d=1 if us==WH else -1
            start=1 if us==WH else 6
            last=7 if us==WH else 0
            r=r0+d
            if ok(r,f0) and p.b[r*8+f0] is None:
                if r==last:
                    for pr in 'qrbn': out.append((sq,r*8+f0,pr))
                else:
                    out.append((sq,r*8+f0,None))
                    if r0==start and p.b[(r0+2*d)*8+f0] is None:
                        out.append((sq,(r0+2*d)*8+f0,None))
            for df in (-1,1):
                r,f=r0+d,f0+df
                if not ok(r,f): continue
                tg=r*8+f
                if p.b[tg] and color(p.b[tg])==them:
                    if r==last:
                        for pr in 'qrbn': out.append((sq,tg,pr))
                    else: out.append((sq,tg,None))
                elif p.ep is not None and tg==p.ep:
                    out.append((sq,tg,None))
        elif t=='N':
            for dr,df in KN:
                r,f=r0+dr,f0+df
                if ok(r,f) and (p.b[r*8+f] is None or color(p.b[r*8+f])==them):
                    out.append((sq,r*8+f,None))
        elif t=='K':
            for dr,df in KG:
                r,f=r0+dr,f0+df
                if ok(r,f) and (p.b[r*8+f] is None or color(p.b[r*8+f])==them):
                    out.append((sq,r*8+f,None))
            if us==WH and sq==4:
                if 'K' in p.cr and p.b[5] is None and p.b[6] is None and p.b[7]=='R' \
                   and not attacked(p,4,BL) and not attacked(p,5,BL) and not attacked(p,6,BL):
                    out.append((4,6,None))
                if 'Q' in p.cr and p.b[3] is None and p.b[2] is None and p.b[1] is None and p.b[0]=='R' \
                   and not attacked(p,4,BL) and not attacked(p,3,BL) and not attacked(p,2,BL):
                    out.append((4,2,None))
            if us==BL and sq==60:
                if 'k' in p.cr and p.b[61] is None and p.b[62] is None and p.b[63]=='r' \
                   and not attacked(p,60,WH) and not attacked(p,61,WH) and not attacked(p,62,WH):
                    out.append((60,62,None))
                if 'q' in p.cr and p.b[59] is None and p.b[58] is None and p.b[57] is None and p.b[56]=='r' \
                   and not attacked(p,60,WH) and not attacked(p,59,WH) and not attacked(p,58,WH):
                    out.append((60,58,None))
        else:
            for dr,df in SL[t]:
                r,f=r0+dr,f0+df
                while ok(r,f):
                    tg=r*8+f
                    if p.b[tg] is None: out.append((sq,tg,None))
                    else:
                        if color(p.b[tg])==them: out.append((sq,tg,None))
                        break
                    r+=dr; f+=df
    return out

def make(p,mv):
    q=p.copy(); a,b,pr=mv; pc=q.b[a]; us=q.stm
    them=BL if us==WH else WH
    if pc.upper()=='P' and q.ep is not None and b==q.ep and q.b[b] is None:
        q.b[b-8 if us==WH else b+8]=None
    q.b[a]=None
    q.b[b]=(pr.upper() if us==WH else pr) if pr else pc
    if pc.upper()=='K' and abs((b&7)-(a&7))==2:
        if b==6: q.b[7]=None; q.b[5]='R'
        elif b==2: q.b[0]=None; q.b[3]='R'
        elif b==62: q.b[63]=None; q.b[61]='r'
        elif b==58: q.b[56]=None; q.b[59]='r'
    for sq,fl in ((4,('K','Q')),(0,('Q',)),(7,('K',)),(60,('k','q')),(56,('q',)),(63,('k',))):
        if a==sq or b==sq:
            for x in fl: q.cr.discard(x)
    q.ep=None
    if pc.upper()=='P' and abs(b-a)==16: q.ep=(a+b)//2
    q.stm=them
    return q

def legal(p):
    res=[]
    for mv in gen(p):
        q=make(p,mv)
        k=ksq(q,p.stm)
        if k is None or not attacked(q,k,q.stm): res.append(mv)
    return res

def nm(mv):
    a,b,pr=mv
    s=chr(97+(a&7))+str((a>>3)+1)+chr(97+(b&7))+str((b>>3)+1)
    return s+(pr if pr else '')

def perft(p,d):
    if d==0: return 1
    if d==1: return len(legal(p))
    return sum(perft(make(p,mv),d-1) for mv in legal(p))

if __name__=='__main__':
    fen=sys.argv[1]; d=int(sys.argv[2])
    p=P(fen)
    tot=0
    for mv in sorted(legal(p), key=nm):
        n=perft(make(p,mv),d-1); tot+=n
        print(nm(mv), n)
    print("total", tot)
