/* ============================================================================
 *  board.c -- representacao, ataques, geracao de lances, SEE, notacao, perft.
 *  Implementacao propria: bitboards + Hyperbola Quintessence para as pecas de
 *  linha e tabela de primeira fileira para as colunas horizontais.
 * ==========================================================================*/
#include "core.h"
#include <ctype.h>
#include <time.h>
#ifdef _WIN32
#  include <windows.h>
#else
#  include <sys/time.h>
#endif

const U64 FILE_BB[8] = {
  0x0101010101010101ULL, 0x0202020202020202ULL, 0x0404040404040404ULL,
  0x0808080808080808ULL, 0x1010101010101010ULL, 0x2020202020202020ULL,
  0x4040404040404040ULL, 0x8080808080808080ULL
};
const U64 RANK_BB[8] = {
  0x00000000000000FFULL, 0x000000000000FF00ULL, 0x0000000000FF0000ULL,
  0x00000000FF000000ULL, 0x000000FF00000000ULL, 0x0000FF0000000000ULL,
  0x00FF000000000000ULL, 0xFF00000000000000ULL
};

/* --------------------------------------------------------------- tabelas    */
static U64 PAWN_ATK[2][64];
static U64 KNIGHT_ATK[64];
static U64 KING_ATK[64];
static U64 DIAG_MASK[64], ANTI_MASK[64], FILE_MASK[64];
static uint8_t RANK_ATK[8][64];

static U64 ZOB_PIECE[12][64];
static U64 ZOB_CASTLE[16];
static U64 ZOB_EP[8];
static U64 ZOB_STM;

double now_ms(void) {
#ifdef _WIN32
  return (double)GetTickCount64();
#else
  struct timeval tv; gettimeofday(&tv, NULL);
  return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
#endif
}

double rng_normal(uint64_t *s) {            /* Box-Muller                   */
  double u1 = rng_unit(s), u2 = rng_unit(s);
  if (u1 < 1e-12) u1 = 1e-12;
  return sqrt(-2.0 * log(u1)) * cos(6.283185307179586 * u2);
}

static int on_board(int f, int r) { return f >= 0 && f < 8 && r >= 0 && r < 8; }

void belief_init(void) {
  static int done = 0;
  if (done) return;
  done = 1;

  for (int s = 0; s < 64; s++) {
    int f = FILE_OF(s), r = RANK_OF(s);
    U64 wp = 0, bp = 0, kn = 0, kg = 0;
    if (on_board(f - 1, r + 1)) wp |= BIT(s + 7);
    if (on_board(f + 1, r + 1)) wp |= BIT(s + 9);
    if (on_board(f - 1, r - 1)) bp |= BIT(s - 9);
    if (on_board(f + 1, r - 1)) bp |= BIT(s - 7);
    PAWN_ATK[WHITE][s] = wp; PAWN_ATK[BLACK][s] = bp;

    static const int kdf[8] = { 1, 2, 2, 1, -1, -2, -2, -1 };
    static const int kdr[8] = { 2, 1, -1, -2, -2, -1, 1, 2 };
    for (int i = 0; i < 8; i++)
      if (on_board(f + kdf[i], r + kdr[i])) kn |= BIT((r + kdr[i]) * 8 + f + kdf[i]);
    KNIGHT_ATK[s] = kn;

    for (int df = -1; df <= 1; df++)
      for (int dr = -1; dr <= 1; dr++)
        if ((df || dr) && on_board(f + df, r + dr)) kg |= BIT((r + dr) * 8 + f + df);
    KING_ATK[s] = kg;

    U64 d = 0, a = 0;
    for (int i = 1; i < 8; i++) {
      if (on_board(f + i, r + i)) d |= BIT((r + i) * 8 + f + i);
      if (on_board(f - i, r - i)) d |= BIT((r - i) * 8 + f - i);
      if (on_board(f + i, r - i)) a |= BIT((r - i) * 8 + f + i);
      if (on_board(f - i, r + i)) a |= BIT((r + i) * 8 + f - i);
    }
    /* HQ exige mascaras SEM a casa de origem (o^(o-2r) precisa do zero la) */
    DIAG_MASK[s] = d;
    ANTI_MASK[s] = a;
    FILE_MASK[s] = FILE_BB[f] & ~BIT(s);
  }

  /* ataques horizontais: para cada coluna do rei-origem e cada ocupacao das
   * 6 casas interiores da fileira.                                         */
  for (int f = 0; f < 8; f++) {
    for (int occ = 0; occ < 64; occ++) {
      unsigned o = (unsigned)(occ << 1);        /* bits 1..6                */
      unsigned atk = 0;
      for (int i = f + 1; i < 8; i++) { atk |= 1u << i; if (o & (1u << i)) break; }
      for (int i = f - 1; i >= 0; i--) { atk |= 1u << i; if (o & (1u << i)) break; }
      RANK_ATK[f][occ] = (uint8_t)atk;
    }
  }

  uint64_t s = 0x1A2B3C4D5E6F7788ULL;
  for (int p = 0; p < 12; p++)
    for (int q = 0; q < 64; q++) ZOB_PIECE[p][q] = rng_next(&s);
  for (int i = 0; i < 16; i++) ZOB_CASTLE[i] = rng_next(&s);
  for (int i = 0; i < 8; i++)  ZOB_EP[i] = rng_next(&s);
  ZOB_STM = rng_next(&s);

  eval_init();
  book_init();
}

/* --------------------------------------------------------------- ataques    */
static inline U64 hq(U64 occ, U64 mask, int sq) {
  U64 fwd = occ & mask;
  U64 rev = __builtin_bswap64(fwd);
  fwd -= BIT(sq);
  rev -= BIT(sq ^ 56);
  fwd ^= __builtin_bswap64(rev);
  return fwd & mask;
}

U64 attacks_pawn(int c, int s)   { return PAWN_ATK[c][s]; }
U64 attacks_knight(int s)        { return KNIGHT_ATK[s]; }
U64 attacks_king(int s)          { return KING_ATK[s]; }

U64 attacks_bishop(int s, U64 occ) {
  return hq(occ, DIAG_MASK[s], s) | hq(occ, ANTI_MASK[s], s);
}
U64 attacks_rook(int s, U64 occ) {
  int r = RANK_OF(s);
  unsigned o = (unsigned)((occ >> (r * 8 + 1)) & 63);
  U64 horiz = (U64)RANK_ATK[FILE_OF(s)][o] << (r * 8);
  return horiz | hq(occ, FILE_MASK[s], s);
}
U64 attacks_queen(int s, U64 occ) { return attacks_bishop(s, occ) | attacks_rook(s, occ); }

U64 attacks_of(const Position *p, int piece, int sq) {
  switch (PC_TYPE(piece)) {
    case PAWN:   return PAWN_ATK[PC_COLOR(piece)][sq];
    case KNIGHT: return KNIGHT_ATK[sq];
    case BISHOP: return attacks_bishop(sq, p->occ[BOTH]);
    case ROOK:   return attacks_rook(sq, p->occ[BOTH]);
    case QUEEN:  return attacks_queen(sq, p->occ[BOTH]);
    default:     return KING_ATK[sq];
  }
}

U64 attackers_to(const Position *p, int sq, int c, U64 occ) {
  U64 r = 0;
  r |= PAWN_ATK[c ^ 1][sq] & p->bb[PIECE(c, PAWN)];
  r |= KNIGHT_ATK[sq]      & p->bb[PIECE(c, KNIGHT)];
  r |= KING_ATK[sq]        & p->bb[PIECE(c, KING)];
  U64 b = attacks_bishop(sq, occ);
  U64 k = attacks_rook(sq, occ);
  r |= b & (p->bb[PIECE(c, BISHOP)] | p->bb[PIECE(c, QUEEN)]);
  r |= k & (p->bb[PIECE(c, ROOK)]   | p->bb[PIECE(c, QUEEN)]);
  return r;
}

int sq_attacked(const Position *p, int sq, int c) {
  if (PAWN_ATK[c ^ 1][sq] & p->bb[PIECE(c, PAWN)])   return 1;
  if (KNIGHT_ATK[sq]      & p->bb[PIECE(c, KNIGHT)]) return 1;
  if (KING_ATK[sq]        & p->bb[PIECE(c, KING)])   return 1;
  U64 occ = p->occ[BOTH];
  if (attacks_bishop(sq, occ) & (p->bb[PIECE(c, BISHOP)] | p->bb[PIECE(c, QUEEN)])) return 1;
  if (attacks_rook(sq, occ)   & (p->bb[PIECE(c, ROOK)]   | p->bb[PIECE(c, QUEEN)])) return 1;
  return 0;
}

int king_sq(const Position *p, int c) {
  U64 k = p->bb[PIECE(c, KING)];
  return k ? lsb(k) : NO_SQ;
}
int in_check(const Position *p, int c) {
  int ks = king_sq(p, c);
  return ks == NO_SQ ? 0 : sq_attacked(p, ks, c ^ 1);
}

/* --------------------------------------------------------------- posicao    */
static void pos_clear(Position *p) {
  memset(p, 0, sizeof(*p));
  memset(p->board, NO_PIECE, 64);
  p->ep = NO_SQ;
}

static void put(Position *p, int pc, int sq) {
  p->board[sq] = (uint8_t)pc;
  p->bb[pc] |= BIT(sq);
  p->occ[PC_COLOR(pc)] |= BIT(sq);
  p->occ[BOTH] |= BIT(sq);
  p->key ^= ZOB_PIECE[pc][sq];
}
static void rem(Position *p, int sq) {
  int pc = p->board[sq];
  p->board[sq] = NO_PIECE;
  p->bb[pc] &= ~BIT(sq);
  p->occ[PC_COLOR(pc)] &= ~BIT(sq);
  p->occ[BOTH] &= ~BIT(sq);
  p->key ^= ZOB_PIECE[pc][sq];
}

static const char *const PIECE_CHAR = "PNBRQKpnbrqk.";

int pos_from_fen(Position *p, const char *fen) {
  pos_clear(p);
  int sq = A8;
  const char *s = fen;
  while (*s && *s != ' ') {
    char c = *s++;
    if (c == '/') { sq -= 16; continue; }
    if (isdigit((unsigned char)c)) { sq += c - '0'; continue; }
    const char *f = strchr(PIECE_CHAR, c);
    if (!f || *f == '.') return 0;
    if (sq < 0 || sq > 63) return 0;
    put(p, (int)(f - PIECE_CHAR), sq);
    sq++;
  }
  while (*s == ' ') s++;
  p->stm = (*s == 'b') ? BLACK : WHITE;
  while (*s && *s != ' ') s++;
  while (*s == ' ') s++;
  p->castle = 0;
  while (*s && *s != ' ') {
    switch (*s) {
      case 'K': p->castle |= CR_WK; break;
      case 'Q': p->castle |= CR_WQ; break;
      case 'k': p->castle |= CR_BK; break;
      case 'q': p->castle |= CR_BQ; break;
      default: break;
    }
    s++;
  }
  while (*s == ' ') s++;
  if (*s && *s != '-') {
    int f = s[0] - 'a', r = s[1] - '1';
    if (f >= 0 && f < 8 && r >= 0 && r < 8) p->ep = r * 8 + f;
    s += 2;
  } else if (*s == '-') s++;
  while (*s == ' ') s++;
  p->halfmove = (uint16_t)atoi(s);
  while (*s && *s != ' ') s++;
  while (*s == ' ') s++;
  p->fullmove = (uint16_t)(*s ? atoi(s) : 1);
  if (!p->fullmove) p->fullmove = 1;

  if (p->stm == BLACK) p->key ^= ZOB_STM;
  p->key ^= ZOB_CASTLE[p->castle];
  if (p->ep != NO_SQ) p->key ^= ZOB_EP[FILE_OF(p->ep)];
  p->ply = 0;
  p->histN = 0;
  p->hist[p->histN++] = p->key;
  return 1;
}

void pos_startpos(Position *p) {
  pos_from_fen(p, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
}

void pos_to_fen(const Position *p, char *out) {
  char *o = out;
  for (int r = 7; r >= 0; r--) {
    int empty = 0;
    for (int f = 0; f < 8; f++) {
      int pc = p->board[r * 8 + f];
      if (pc == NO_PIECE) { empty++; continue; }
      if (empty) { *o++ = (char)('0' + empty); empty = 0; }
      *o++ = PIECE_CHAR[pc];
    }
    if (empty) *o++ = (char)('0' + empty);
    if (r) *o++ = '/';
  }
  o += sprintf(o, " %c ", p->stm == WHITE ? 'w' : 'b');
  if (!p->castle) *o++ = '-';
  else {
    if (p->castle & CR_WK) *o++ = 'K';
    if (p->castle & CR_WQ) *o++ = 'Q';
    if (p->castle & CR_BK) *o++ = 'k';
    if (p->castle & CR_BQ) *o++ = 'q';
  }
  if (p->ep == NO_SQ) o += sprintf(o, " - ");
  else o += sprintf(o, " %c%c ", 'a' + FILE_OF(p->ep), '1' + RANK_OF(p->ep));
  sprintf(o, "%d %d", p->halfmove, p->fullmove);
}

void pos_print(const Position *p) {
  static const char *GLYPH[13] = { "P","N","B","R","Q","K",
                                   "p","n","b","r","q","k","." };
  printf("\n   +------------------------+\n");
  for (int r = 7; r >= 0; r--) {
    printf(" %d |", r + 1);
    for (int f = 0; f < 8; f++) printf(" %s ", GLYPH[p->board[r * 8 + f]]);
    printf("|\n");
  }
  printf("   +------------------------+\n     a  b  c  d  e  f  g  h\n");
  char fen[128]; pos_to_fen(p, fen);
  printf("   %s\n\n", fen);
}

/* --------------------------------------------------- geracao de lances      */
static inline void add(MoveList *l, Move m) { if (l->n < MAX_MOVES) l->m[l->n++] = m; }

static void gen_pawns(const Position *p, MoveList *l, int caps_only) {
  int us = p->stm, them = us ^ 1;
  U64 pawns = p->bb[PIECE(us, PAWN)];
  U64 empty = ~p->occ[BOTH];
  U64 enemy = p->occ[them];
  int up = us == WHITE ? 8 : -8;
  U64 promo_rank = us == WHITE ? RANK_BB[7] : RANK_BB[0];
  U64 start_rank = us == WHITE ? RANK_BB[1] : RANK_BB[6];

  if (!caps_only) {
    U64 one = (us == WHITE ? pawns << 8 : pawns >> 8) & empty;
    U64 two = (us == WHITE ? (one & RANK_BB[2]) << 8 : (one & RANK_BB[5]) >> 8) & empty;
    U64 q = one & ~promo_rank;
    while (q) { int t = pop_lsb(&q); add(l, MK_MOVE(t - up, t, MF_QUIET)); }
    while (two) { int t = pop_lsb(&two); add(l, MK_MOVE(t - 2 * up, t, MF_DPUSH)); }
    q = one & promo_rank;
    while (q) {
      int t = pop_lsb(&q), f = t - up;
      add(l, MK_MOVE(f, t, MF_PQ)); add(l, MK_MOVE(f, t, MF_PR));
      add(l, MK_MOVE(f, t, MF_PB)); add(l, MK_MOVE(f, t, MF_PN));
    }
  } else {
    /* promocoes a dama contam como "lance forcante" mesmo sem captura */
    U64 one = (us == WHITE ? pawns << 8 : pawns >> 8) & empty & promo_rank;
    while (one) { int t = pop_lsb(&one); add(l, MK_MOVE(t - up, t, MF_PQ)); }
  }
  (void)start_rank;

  U64 src = pawns;
  while (src) {
    int f = pop_lsb(&src);
    U64 a = PAWN_ATK[us][f] & enemy;
    while (a) {
      int t = pop_lsb(&a);
      if (BIT(t) & promo_rank) {
        add(l, MK_MOVE(f, t, MF_PQC)); add(l, MK_MOVE(f, t, MF_PRC));
        add(l, MK_MOVE(f, t, MF_PBC)); add(l, MK_MOVE(f, t, MF_PNC));
      } else add(l, MK_MOVE(f, t, MF_CAP));
    }
    if (p->ep != NO_SQ && (PAWN_ATK[us][f] & BIT(p->ep)))
      add(l, MK_MOVE(f, p->ep, MF_EP));
  }
}

static void gen_piece(const Position *p, MoveList *l, int pt, U64 target) {
  int us = p->stm;
  U64 src = p->bb[PIECE(us, pt)];
  while (src) {
    int f = pop_lsb(&src);
    U64 a = attacks_of(p, PIECE(us, pt), f) & target;
    while (a) {
      int t = pop_lsb(&a);
      add(l, MK_MOVE(f, t, p->board[t] == NO_PIECE ? MF_QUIET : MF_CAP));
    }
  }
}

static void gen_castles(const Position *p, MoveList *l) {
  int us = p->stm, them = us ^ 1;
  U64 occ = p->occ[BOTH];
  if (us == WHITE) {
    if (king_sq(p, WHITE) != E1) return;
    if (sq_attacked(p, E1, them)) return;
    if ((p->castle & CR_WK) && !(occ & (BIT(F1) | BIT(G1))) &&
        p->board[H1] == PIECE(WHITE, ROOK) && !sq_attacked(p, F1, them))
      add(l, MK_MOVE(E1, G1, MF_KCASTLE));
    if ((p->castle & CR_WQ) && !(occ & (BIT(D1) | BIT(C1) | BIT(B1))) &&
        p->board[A1] == PIECE(WHITE, ROOK) && !sq_attacked(p, D1, them))
      add(l, MK_MOVE(E1, C1, MF_QCASTLE));
  } else {
    if (king_sq(p, BLACK) != E8) return;
    if (sq_attacked(p, E8, them)) return;
    if ((p->castle & CR_BK) && !(occ & (BIT(F8) | BIT(G8))) &&
        p->board[H8] == PIECE(BLACK, ROOK) && !sq_attacked(p, F8, them))
      add(l, MK_MOVE(E8, G8, MF_KCASTLE));
    if ((p->castle & CR_BQ) && !(occ & (BIT(D8) | BIT(C8) | BIT(B8))) &&
        p->board[A8] == PIECE(BLACK, ROOK) && !sq_attacked(p, D8, them))
      add(l, MK_MOVE(E8, C8, MF_QCASTLE));
  }
}

void gen_pseudo(const Position *p, MoveList *l) {
  l->n = 0;
  U64 target = ~p->occ[p->stm];
  gen_pawns(p, l, 0);
  for (int pt = KNIGHT; pt <= KING; pt++) gen_piece(p, l, pt, target);
  gen_castles(p, l);
}

void gen_pseudo_captures(const Position *p, MoveList *l) {
  l->n = 0;
  U64 target = p->occ[p->stm ^ 1];
  gen_pawns(p, l, 1);
  for (int pt = KNIGHT; pt <= KING; pt++) gen_piece(p, l, pt, target);
}

void gen_legal(const Position *p, MoveList *l) {
  MoveList tmp;
  gen_pseudo(p, &tmp);
  Position q = *p;
  l->n = 0;
  for (int i = 0; i < tmp.n; i++)
    if (do_move(&q, tmp.m[i])) { undo_move(&q); add(l, tmp.m[i]); }
}

int move_is_legal(const Position *p, Move m) {
  MoveList l; gen_legal(p, &l);
  for (int i = 0; i < l.n; i++) if (l.m[i] == m) return 1;
  return 0;
}

/* --------------------------------------------------- aplicar / desfazer     */
static const uint8_t CASTLE_MASK[64] = {
  ~CR_WQ & 15, 15, 15, 15, (uint8_t)(~(CR_WQ | CR_WK) & 15), 15, 15, ~CR_WK & 15,
  15,15,15,15,15,15,15,15,  15,15,15,15,15,15,15,15,  /* r2 r3 */
  15,15,15,15,15,15,15,15,  15,15,15,15,15,15,15,15,  /* r4 r5 */
  15,15,15,15,15,15,15,15,  15,15,15,15,15,15,15,15,  /* r6 r7 */
  ~CR_BQ & 15, 15, 15, 15, (uint8_t)(~(CR_BQ | CR_BK) & 15), 15, 15, ~CR_BK & 15
};

int do_move(Position *p, Move m) {
  int us = p->stm, them = us ^ 1;
  int from = M_FROM(m), to = M_TO(m), fl = M_FLAG(m);
  Undo *u = &p->stack[p->ply];
  u->move = m; u->castle = p->castle; u->ep = p->ep;
  u->halfmove = p->halfmove; u->key = p->key;
  u->captured = NO_PIECE;

  int pc = p->board[from];
  if (p->ep != NO_SQ) p->key ^= ZOB_EP[FILE_OF(p->ep)];
  p->key ^= ZOB_CASTLE[p->castle];

  p->halfmove++;
  if (PC_TYPE(pc) == PAWN) p->halfmove = 0;

  if (fl == MF_EP) {
    int cs = us == WHITE ? to - 8 : to + 8;
    u->captured = p->board[cs];
    rem(p, cs);
  } else if (p->board[to] != NO_PIECE) {
    u->captured = p->board[to];
    rem(p, to);
    p->halfmove = 0;
  }

  rem(p, from);
  if (M_IS_PROMO(m)) put(p, PIECE(us, M_PROMO_PT(m)), to);
  else               put(p, pc, to);

  if (fl == MF_KCASTLE) {
    int rf = us == WHITE ? H1 : H8, rt = us == WHITE ? F1 : F8;
    rem(p, rf); put(p, PIECE(us, ROOK), rt);
  } else if (fl == MF_QCASTLE) {
    int rf = us == WHITE ? A1 : A8, rt = us == WHITE ? D1 : D8;
    rem(p, rf); put(p, PIECE(us, ROOK), rt);
  }

  p->castle &= CASTLE_MASK[from];
  p->castle &= CASTLE_MASK[to];
  p->key ^= ZOB_CASTLE[p->castle];

  p->ep = NO_SQ;
  if (fl == MF_DPUSH) {
    int epsq = us == WHITE ? from + 8 : from - 8;
    /* so registra se houver peao inimigo capaz de capturar (chaves estaveis) */
    if (PAWN_ATK[us][epsq] & p->bb[PIECE(them, PAWN)]) {
      p->ep = epsq;
      p->key ^= ZOB_EP[FILE_OF(epsq)];
    }
  }

  p->stm = (uint8_t)them;
  p->key ^= ZOB_STM;
  if (us == BLACK) p->fullmove++;
  p->ply++;
  p->hist[p->histN++] = p->key;

  if (in_check(p, us)) { undo_move(p); return 0; }
  return 1;
}

void undo_move(Position *p) {
  p->ply--;
  p->histN--;
  Undo *u = &p->stack[p->ply];
  Move m = u->move;
  int to = M_TO(m), from = M_FROM(m), fl = M_FLAG(m);
  int them = p->stm, us = them ^ 1;

  if (us == BLACK) p->fullmove--;
  p->stm = (uint8_t)us;

  int pc = p->board[to];
  rem(p, to);
  if (M_IS_PROMO(m)) put(p, PIECE(us, PAWN), from);
  else               put(p, pc, from);

  if (fl == MF_KCASTLE) {
    int rf = us == WHITE ? H1 : H8, rt = us == WHITE ? F1 : F8;
    rem(p, rt); put(p, PIECE(us, ROOK), rf);
  } else if (fl == MF_QCASTLE) {
    int rf = us == WHITE ? A1 : A8, rt = us == WHITE ? D1 : D8;
    rem(p, rt); put(p, PIECE(us, ROOK), rf);
  }

  if (u->captured != NO_PIECE) {
    if (fl == MF_EP) put(p, u->captured, us == WHITE ? to - 8 : to + 8);
    else             put(p, u->captured, to);
  }

  p->castle = u->castle; p->ep = u->ep;
  p->halfmove = u->halfmove; p->key = u->key;
}

void do_null(Position *p) {
  Undo *u = &p->stack[p->ply];
  u->move = MOVE_NONE; u->castle = p->castle; u->ep = p->ep;
  u->halfmove = p->halfmove; u->key = p->key; u->captured = NO_PIECE;
  if (p->ep != NO_SQ) p->key ^= ZOB_EP[FILE_OF(p->ep)];
  p->ep = NO_SQ;
  p->stm ^= 1;
  p->key ^= ZOB_STM;
  p->ply++;
  p->hist[p->histN++] = p->key;
}
void undo_null(Position *p) {
  p->ply--; p->histN--;
  Undo *u = &p->stack[p->ply];
  p->stm ^= 1; p->castle = u->castle; p->ep = u->ep;
  p->halfmove = u->halfmove; p->key = u->key;
}

int is_repetition(const Position *p) {
  int cnt = 0;
  int stop = p->histN - 1 - p->halfmove;
  if (stop < 0) stop = 0;
  for (int i = p->histN - 3; i >= stop; i -= 2)
    if (p->hist[i] == p->key && ++cnt >= 1) return 1;
  return 0;
}

int is_draw_material(const Position *p) {
  if (p->bb[PIECE(WHITE, PAWN)] || p->bb[PIECE(BLACK, PAWN)]) return 0;
  if (p->bb[PIECE(WHITE, QUEEN)] || p->bb[PIECE(BLACK, QUEEN)]) return 0;
  if (p->bb[PIECE(WHITE, ROOK)] || p->bb[PIECE(BLACK, ROOK)]) return 0;
  int wn = popcount(p->bb[PIECE(WHITE, KNIGHT)]), wb = popcount(p->bb[PIECE(WHITE, BISHOP)]);
  int bn = popcount(p->bb[PIECE(BLACK, KNIGHT)]), bb = popcount(p->bb[PIECE(BLACK, BISHOP)]);
  if (wn + wb <= 1 && bn + bb <= 1) return 1;          /* K(+m) vs K(+m)    */
  if (wb == 0 && bb == 0 && wn <= 2 && bn == 0) return 1;
  if (wb == 0 && bb == 0 && bn <= 2 && wn == 0) return 1;
  return 0;
}

/* ------------------------------------------------------------------- SEE    */
static const int SEE_VAL[6] = { 100, 320, 330, 500, 950, 20000 };

static U64 see_least(const Position *p, U64 attackers, int side, int *pt) {
  for (int t = PAWN; t <= KING; t++) {
    U64 s = attackers & p->bb[PIECE(side, t)];
    if (s) { *pt = t; return s & -s; }
  }
  return 0;
}

int see(const Position *p, Move m) {
  int to = M_TO(m), from = M_FROM(m);
  int us = p->stm;
  int gain[32], d = 0;

  int captured = (M_FLAG(m) == MF_EP) ? PAWN
               : (p->board[to] == NO_PIECE ? NO_PTYPE : PC_TYPE(p->board[to]));
  gain[0] = captured == NO_PTYPE ? 0 : SEE_VAL[captured];
  if (M_IS_PROMO(m)) gain[0] += SEE_VAL[M_PROMO_PT(m)] - SEE_VAL[PAWN];

  int moving = PC_TYPE(p->board[from]);
  if (M_IS_PROMO(m)) moving = M_PROMO_PT(m);

  U64 occ = p->occ[BOTH] & ~BIT(from);
  if (M_FLAG(m) == MF_EP) occ &= ~BIT(us == WHITE ? to - 8 : to + 8);
  occ |= BIT(to);

  U64 may_slide = p->bb[PIECE(WHITE, BISHOP)] | p->bb[PIECE(BLACK, BISHOP)] |
                  p->bb[PIECE(WHITE, ROOK)]   | p->bb[PIECE(BLACK, ROOK)]   |
                  p->bb[PIECE(WHITE, QUEEN)]  | p->bb[PIECE(BLACK, QUEEN)];
  U64 atk = attackers_to(p, to, WHITE, occ) | attackers_to(p, to, BLACK, occ);
  atk &= occ;

  int side = us ^ 1;
  int on_sq = moving;
  while (1) {
    d++;
    gain[d] = SEE_VAL[on_sq] - gain[d - 1];
    int pt;
    U64 pick = see_least(p, atk & p->occ[side] & occ, side, &pt);
    if (!pick) break;
    occ &= ~pick;
    atk &= ~pick;
    if (pt == PAWN || pt == BISHOP || pt == QUEEN)
      atk |= attacks_bishop(to, occ) & may_slide & occ;
    if (pt == ROOK || pt == QUEEN)
      atk |= attacks_rook(to, occ) & may_slide & occ;
    atk &= occ;
    on_sq = pt;
    side ^= 1;
    if (d > 29) break;
  }
  /* reducao negamax do algoritmo de troca */
  while (--d > 0) {
    int a = -gain[d - 1], b = gain[d];
    gain[d - 1] = -(a > b ? a : b);
  }
  return gain[0];
}

int see_sq(const Position *p, int sq, int side) {
  if (p->board[sq] == NO_PIECE) return 0;
  Position q = *p;
  q.stm = (uint8_t)side;
  MoveList l;
  gen_pseudo_captures(&q, &l);
  int best = 0;
  for (int i = 0; i < l.n; i++)
    if (M_TO(l.m[i]) == sq) { int v = see(&q, l.m[i]); if (v > best) best = v; }
  return best;
}

/* --------------------------------------------------------------- notacao    */
void move_to_uci(Move m, char *out) {
  int f = M_FROM(m), t = M_TO(m);
  out[0] = (char)('a' + FILE_OF(f)); out[1] = (char)('1' + RANK_OF(f));
  out[2] = (char)('a' + FILE_OF(t)); out[3] = (char)('1' + RANK_OF(t));
  if (M_IS_PROMO(m)) { out[4] = "nbrq"[M_FLAG(m) & 3]; out[5] = 0; }
  else out[4] = 0;
}

Move move_from_uci(const Position *p, const char *s) {
  MoveList l; gen_legal(p, &l);
  char buf[8];
  for (int i = 0; i < l.n; i++) {
    move_to_uci(l.m[i], buf);
    if (!strncmp(buf, s, strlen(buf)) && strlen(buf) == strlen(s)) return l.m[i];
  }
  /* tolera "e7e8" sem indicar promocao -> assume dama */
  if (strlen(s) == 4) {
    for (int i = 0; i < l.n; i++) {
      move_to_uci(l.m[i], buf);
      if (!strncmp(buf, s, 4) && (M_FLAG(l.m[i]) == MF_PQ || M_FLAG(l.m[i]) == MF_PQC))
        return l.m[i];
    }
  }
  return MOVE_NONE;
}

void move_to_san(const Position *p, Move m, char *out) {
  char *o = out;
  int from = M_FROM(m), to = M_TO(m), fl = M_FLAG(m);
  int pc = p->board[from], pt = PC_TYPE(pc);

  if (fl == MF_KCASTLE) { strcpy(out, "O-O"); goto suffix; }
  if (fl == MF_QCASTLE) { strcpy(out, "O-O-O"); goto suffix; }

  if (pt != PAWN) {
    *o++ = "PNBRQK"[pt];
    MoveList l; gen_legal(p, &l);
    int same_file = 0, same_rank = 0, ambiguous = 0;
    for (int i = 0; i < l.n; i++) {
      Move x = l.m[i];
      if (x == m || M_TO(x) != to) continue;
      if (PC_TYPE(p->board[M_FROM(x)]) != pt) continue;
      ambiguous = 1;
      if (FILE_OF(M_FROM(x)) == FILE_OF(from)) same_file = 1;
      if (RANK_OF(M_FROM(x)) == RANK_OF(from)) same_rank = 1;
    }
    if (ambiguous) {
      if (!same_file) *o++ = (char)('a' + FILE_OF(from));
      else if (!same_rank) *o++ = (char)('1' + RANK_OF(from));
      else { *o++ = (char)('a' + FILE_OF(from)); *o++ = (char)('1' + RANK_OF(from)); }
    }
  } else if (M_IS_CAP(m) || fl == MF_EP) {
    *o++ = (char)('a' + FILE_OF(from));
  }
  if (M_IS_CAP(m) || fl == MF_EP) *o++ = 'x';
  *o++ = (char)('a' + FILE_OF(to));
  *o++ = (char)('1' + RANK_OF(to));
  if (M_IS_PROMO(m)) { *o++ = '='; *o++ = "NBRQ"[M_FLAG(m) & 3]; }
  *o = 0;

suffix: {
    Position q = *p;
    if (do_move(&q, m)) {
      int chk = in_check(&q, q.stm);
      MoveList l; gen_legal(&q, &l);
      char *e = out + strlen(out);
      if (chk) *e++ = l.n ? '+' : '#';
      *e = 0;
      undo_move(&q);
    }
  }
}

static void san_normalize(const char *in, char *out) {
  int j = 0;
  for (int i = 0; in[i]; i++) {
    char c = in[i];
    if (c == '+' || c == '#' || c == '!' || c == '?' || c == ' ') continue;
    if (c == '0') c = 'O';
    out[j++] = c;
  }
  out[j] = 0;
}

Move move_from_san(const Position *p, const char *s) {
  char want[32], got[32], gn[32];
  san_normalize(s, want);
  MoveList l; gen_legal(p, &l);
  for (int i = 0; i < l.n; i++) {
    move_to_san(p, l.m[i], got);
    san_normalize(got, gn);
    if (!strcmp(gn, want)) return l.m[i];
  }
  /* tolera promocao sem '=' e captura sem 'x' */
  for (int i = 0; i < l.n; i++) {
    move_to_san(p, l.m[i], got);
    san_normalize(got, gn);
    char a[32]; int k = 0;
    for (int j = 0; gn[j]; j++) if (gn[j] != '=' && gn[j] != 'x') a[k++] = gn[j];
    a[k] = 0;
    char b[32]; k = 0;
    for (int j = 0; want[j]; j++) if (want[j] != '=' && want[j] != 'x') b[k++] = want[j];
    b[k] = 0;
    if (!strcmp(a, b)) return l.m[i];
  }
  return MOVE_NONE;
}

Move parse_move(const Position *p, const char *s) {
  Move m = move_from_uci(p, s);
  if (m != MOVE_NONE) return m;
  return move_from_san(p, s);
}

/* ------------------------------------------------------------------- perft  */
U64 perft(Position *p, int depth) {
  if (depth == 0) return 1;
  MoveList l; gen_pseudo(p, &l);
  U64 n = 0;
  for (int i = 0; i < l.n; i++) {
    if (!do_move(p, l.m[i])) continue;
    n += depth == 1 ? 1 : perft(p, depth - 1);
    undo_move(p);
  }
  return n;
}
