/* ============================================================================
 *  eval.c -- Avaliacao como CRENCA.
 *
 *  A funcao nao devolve "centipeoes". Ela devolve (mu, sigma):
 *    mu    -> pontuacao esperada das brancas em [0,1]
 *    sigma -> o quanto a propria engine desconfia dessa estimativa
 *
 *  sigma e o coracao da engine: e ele que diz a busca onde vale a pena olhar.
 *  Posicoes tacticamente carregadas (pecas penduradas, reis expostos, damas
 *  no tabuleiro, muitos xeques disponiveis) produzem sigma alto; finais
 *  tecnicos e posicoes travadas produzem sigma baixo.
 * ==========================================================================*/
#include "core.h"

/* ------------------------------------------------------- valores e tabelas */
static const int MG_VAL[6] = {  85, 325, 340, 480,  960, 0 };
static const int EG_VAL[6] = { 105, 330, 355, 545, 1010, 0 };
static const int PHASE_W[6] = { 0, 1, 1, 2, 4, 0 };

/* tabelas escritas da 8a fileira para a 1a (visao das brancas) */
#define T(...) { __VA_ARGS__ }
static const int MG_RAW[6][64] = {
 /* PEAO */ T(
   0,  0,  0,  0,  0,  0,  0,  0,
  98,134, 61, 95, 68,126, 34,-11,
  -6,  7, 26, 31, 65, 56, 25,-20,
 -14, 13,  6, 21, 23, 12, 17,-23,
 -27, -2, -5, 12, 17,  6, 10,-25,
 -26, -4, -4,-10,  3,  3, 33,-12,
 -35, -1,-20,-23,-15, 24, 38,-22,
   0,  0,  0,  0,  0,  0,  0,  0),
 /* CAVALO */ T(
-167,-89,-34,-49, 61,-97,-15,-107,
 -73,-41, 72, 36, 23, 62,  7, -17,
 -47, 60, 37, 65, 84,129, 73,  44,
  -9, 17, 19, 53, 37, 69, 18,  22,
 -13,  4, 16, 13, 28, 19, 21,  -8,
 -23, -9, 12, 10, 19, 17, 25, -16,
 -29,-53,-12, -3, -1, 18,-14, -19,
-105,-21,-58,-33,-17,-28,-19, -23),
 /* BISPO */ T(
 -29,  4,-82,-37,-25,-42,  7, -8,
 -26, 16,-18,-13, 30, 59, 18,-47,
 -16, 37, 43, 40, 35, 50, 37, -2,
  -4,  5, 19, 50, 37, 37,  7, -2,
  -6, 13, 13, 26, 34, 12, 10,  4,
   0, 15, 15, 15, 14, 27, 18, 10,
   4, 15, 16,  0,  7, 21, 33,  1,
 -33, -3,-14,-21,-13,-12,-39,-21),
 /* TORRE */ T(
  32, 42, 32, 51, 63,  9, 31, 43,
  27, 32, 58, 62, 80, 67, 26, 44,
  -5, 19, 26, 36, 17, 45, 61, 16,
 -24,-11,  7, 26, 24, 35, -8,-20,
 -36,-26,-12, -1,  9, -7,  6,-23,
 -45,-25,-16,-17,  3,  0, -5,-33,
 -44,-16,-20, -9, -1, 11, -6,-71,
 -19,-13,  1, 17, 16,  7,-37,-26),
 /* DAMA */ T(
 -28,  0, 29, 12, 59, 44, 43, 45,
 -24,-39, -5,  1,-16, 57, 28, 54,
 -13,-17,  7,  8, 29, 56, 47, 57,
 -27,-27,-16,-16, -1, 17, -2,  1,
  -9,-26, -9,-10, -2, -4,  3, -3,
 -14,  2,-11, -2, -5,  2, 14,  5,
 -35, -8, 11,  2,  8, 15, -3,  1,
  -1,-18, -9, 10,-15,-25,-31,-50),
 /* REI */ T(
 -65, 23, 16,-15,-56,-34,  2, 13,
  29, -1,-20, -7, -8, -4,-38,-29,
  -9, 24,  2,-16,-20,  6, 22,-22,
 -17,-20,-12,-27,-30,-25,-14,-36,
 -49, -1,-27,-39,-46,-44,-33,-51,
 -14,-14,-22,-46,-44,-30,-15,-27,
   1,  7, -8,-64,-43,-16,  9,  8,
 -15, 36, 12,-54,  8,-28, 24, 14)
};
static const int EG_RAW[6][64] = {
 /* PEAO */ T(
   0,  0,  0,  0,  0,  0,  0,  0,
 178,173,158,134,147,132,165,187,
  94,100, 85, 67, 56, 53, 82, 84,
  32, 24, 13,  5, -2,  4, 17, 17,
  13,  9, -3, -7, -7, -8,  3, -1,
   4,  7, -6,  1,  0, -5, -1, -8,
  13,  8,  8, 10, 13,  0,  2, -7,
   0,  0,  0,  0,  0,  0,  0,  0),
 /* CAVALO */ T(
 -58,-38,-13,-28,-31,-27,-63,-99,
 -25, -8,-25, -2, -9,-25,-24,-52,
 -24,-20, 10,  9, -1, -9,-19,-41,
 -17,  3, 22, 22, 22, 11,  8,-18,
 -18, -6, 16, 25, 16, 17,  4,-18,
 -23, -3, -1, 15, 10, -3,-20,-22,
 -42,-20,-10, -5, -2,-20,-23,-44,
 -29,-51,-23,-15,-22,-18,-50,-64),
 /* BISPO */ T(
 -14,-21,-11, -8, -7, -9,-17,-24,
  -8, -4,  7,-12, -3,-13, -4,-14,
   2, -8,  0, -1, -2,  6,  0,  4,
  -3,  9, 12,  9, 14, 10,  3,  2,
  -6,  3, 13, 19,  7, 10, -3, -9,
 -12, -3,  8, 10, 13,  3, -7,-15,
 -14,-18, -7, -1,  4, -9,-15,-27,
 -23, -9,-23, -5, -9,-16, -5,-17),
 /* TORRE */ T(
  13, 10, 18, 15, 12, 12,  8,  5,
  11, 13, 13, 11, -3,  3,  8,  3,
   7,  7,  7,  5,  4, -3, -5, -3,
   4,  3, 13,  1,  2,  1, -1,  2,
   3,  5,  8,  4, -5, -6, -8,-11,
  -4,  0, -5, -1, -7,-12, -8,-16,
  -6, -6,  0,  2, -9, -9,-11, -3,
  -9,  2,  3, -1, -5,-13,  4,-20),
 /* DAMA */ T(
  -9, 22, 22, 27, 27, 19, 10, 20,
 -17, 20, 32, 41, 58, 25, 30,  0,
 -20,  6,  9, 49, 47, 35, 19,  9,
   3, 22, 24, 45, 57, 40, 57, 36,
 -18, 28, 19, 47, 31, 34, 39, 23,
 -16,-27, 15,  6,  9, 17, 10,  5,
 -22,-23,-30,-16,-16,-23,-36,-32,
 -33,-28,-22,-43, -5,-32,-20,-41),
 /* REI */ T(
 -74,-35,-18,-18,-11, 15,  4,-17,
 -12, 17, 14, 17, 17, 38, 23, 11,
  10, 17, 23, 15, 20, 45, 44, 13,
  -8, 22, 24, 27, 26, 33, 26,  3,
 -18, -4, 21, 24, 27, 23,  9,-11,
 -19, -3, 11, 21, 23, 16,  7, -9,
 -27,-11,  4, 13, 14,  4, -5,-17,
 -53,-34,-21,-11,-28,-14,-24,-43)
};
#undef T

static int MG_PST[12][64], EG_PST[12][64];
static U64 PASSED[2][64], FRONTSPAN[2][64], ADJ_FILES[8], KZONE[64];

void eval_init(void) {
  static int done = 0; if (done) return; done = 1;
  for (int pt = 0; pt < 6; pt++)
    for (int s = 0; s < 64; s++) {
      int wsq = (7 - RANK_OF(s)) * 8 + FILE_OF(s);   /* tabela vem invertida */
      MG_PST[PIECE(WHITE, pt)][s] = MG_VAL[pt] + MG_RAW[pt][wsq];
      EG_PST[PIECE(WHITE, pt)][s] = EG_VAL[pt] + EG_RAW[pt][wsq];
      int bs = s ^ 56;
      MG_PST[PIECE(BLACK, pt)][bs] = MG_VAL[pt] + MG_RAW[pt][wsq];
      EG_PST[PIECE(BLACK, pt)][bs] = EG_VAL[pt] + EG_RAW[pt][wsq];
    }
  for (int f = 0; f < 8; f++) {
    ADJ_FILES[f] = 0;
    if (f > 0) ADJ_FILES[f] |= FILE_BB[f - 1];
    if (f < 7) ADJ_FILES[f] |= FILE_BB[f + 1];
  }
  for (int s = 0; s < 64; s++) {
    int r = RANK_OF(s), f = FILE_OF(s);
    U64 up = 0, dn = 0;
    for (int i = r + 1; i < 8; i++) up |= RANK_BB[i];
    for (int i = r - 1; i >= 0; i--) dn |= RANK_BB[i];
    FRONTSPAN[WHITE][s] = up & FILE_BB[f];
    FRONTSPAN[BLACK][s] = dn & FILE_BB[f];
    PASSED[WHITE][s] = up & (FILE_BB[f] | ADJ_FILES[f]);
    PASSED[BLACK][s] = dn & (FILE_BB[f] | ADJ_FILES[f]);
    U64 z = attacks_king(s) | BIT(s);
    if (r < 6) z |= attacks_king(s + 8) | BIT(s + 8);
    if (r > 1) z |= attacks_king(s - 8) | BIT(s - 8);
    KZONE[s] = z;
  }
}

int game_phase(const Position *p) {
  int ph = 0;
  for (int c = 0; c < 2; c++)
    for (int pt = KNIGHT; pt <= QUEEN; pt++)
      ph += PHASE_W[pt] * popcount(p->bb[PIECE(c, pt)]);
  if (ph > 24) ph = 24;
  return ph * 256 / 24;
}

/* ------------------------------------------------------------- componentes */
typedef struct {
  U64 att[2];          /* todas as casas atacadas por cada cor               */
  U64 att2[2];         /* atacadas 2+ vezes                                  */
  U64 pawn_att[2];
  int kzone_att[2];    /* unidades de ataque contra o rei adversario         */
  int kzone_cnt[2];
  int mob_mg[2], mob_eg[2];
} AttInfo;

static void collect(const Position *p, AttInfo *a) {
  memset(a, 0, sizeof(*a));
  U64 occ = p->occ[BOTH];
  for (int c = 0; c < 2; c++) {
    U64 pw = p->bb[PIECE(c, PAWN)];
    a->pawn_att[c] = c == WHITE
      ? ((pw & ~FILE_BB[0]) << 7) | ((pw & ~FILE_BB[7]) << 9)
      : ((pw & ~FILE_BB[0]) >> 9) | ((pw & ~FILE_BB[7]) >> 7);
    a->att[c] = a->pawn_att[c];
  }
  for (int c = 0; c < 2; c++) {
    int eks = king_sq(p, c ^ 1);
    U64 zone = eks == NO_SQ ? 0 : KZONE[eks];
    U64 safe = ~a->pawn_att[c ^ 1] & ~p->occ[c];
    static const int MOBW_MG[6] = { 0, 4, 4, 2, 1, 0 };
    static const int MOBW_EG[6] = { 0, 4, 4, 5, 3, 0 };
    static const int KATT_W[6]  = { 0, 2, 2, 3, 5, 0 };
    for (int pt = KNIGHT; pt <= KING; pt++) {
      U64 b = p->bb[PIECE(c, pt)];
      while (b) {
        int s = pop_lsb(&b);
        U64 at = attacks_of(p, PIECE(c, pt), s);
        a->att2[c] |= a->att[c] & at;
        a->att[c] |= at;
        if (pt != KING) {
          int m = popcount(at & safe);
          a->mob_mg[c] += MOBW_MG[pt] * (m - 4);
          a->mob_eg[c] += MOBW_EG[pt] * (m - 4);
          U64 z = at & zone;
          if (z) { a->kzone_att[c] += KATT_W[pt] * popcount(z); a->kzone_cnt[c]++; }
        }
      }
    }
  }
  (void)occ;
}

static int pawn_eval(const Position *p, int c, int *eg_out) {
  int mg = 0, eg = 0;
  U64 own = p->bb[PIECE(c, PAWN)], opp = p->bb[PIECE(c ^ 1, PAWN)];
  U64 b = own;
  while (b) {
    int s = pop_lsb(&b);
    int f = FILE_OF(s);
    int rel = c == WHITE ? RANK_OF(s) : 7 - RANK_OF(s);
    int doubled  = (FRONTSPAN[c][s] & own) != 0;
    int isolated = (ADJ_FILES[f] & own) == 0;
    int passed   = (PASSED[c][s] & opp) == 0 && !doubled;
    int connected = (attacks_pawn(c ^ 1, s) & own) != 0 ||
                    (ADJ_FILES[f] & RANK_BB[RANK_OF(s)] & own) != 0;
    if (doubled)  { mg -= 12; eg -= 26; }
    if (isolated) { mg -= 14; eg -= 18; }
    if (connected){ mg += 7 + rel * 2; eg += 5 + rel * 3; }
    if (passed) {
      static const int PB_MG[8] = { 0, 5, 10, 22, 45, 80, 130, 0 };
      static const int PB_EG[8] = { 0, 12, 20, 40, 75, 125, 195, 0 };
      mg += PB_MG[rel]; eg += PB_EG[rel];
      /* final: distancia dos reis ao peao passado                           */
      int ks_us = king_sq(p, c), ks_th = king_sq(p, c ^ 1);
      int push = c == WHITE ? s + 8 : s - 8;
      if (push >= 0 && push < 64 && ks_th != NO_SQ && ks_us != NO_SQ) {
        int dt = abs(FILE_OF(ks_th) - FILE_OF(push)) > abs(RANK_OF(ks_th) - RANK_OF(push))
               ? abs(FILE_OF(ks_th) - FILE_OF(push)) : abs(RANK_OF(ks_th) - RANK_OF(push));
        int du = abs(FILE_OF(ks_us) - FILE_OF(push)) > abs(RANK_OF(ks_us) - RANK_OF(push))
               ? abs(FILE_OF(ks_us) - FILE_OF(push)) : abs(RANK_OF(ks_us) - RANK_OF(push));
        eg += (dt - du) * 5 * (rel - 1 > 0 ? rel - 1 : 0);
      }
    }
  }
  *eg_out = eg;
  return mg;
}

static int king_safety(const Position *p, const AttInfo *a, int c, const Style *st) {
  int ks = king_sq(p, c);
  if (ks == NO_SQ) return 0;
  int f = FILE_OF(ks);
  U64 own = p->bb[PIECE(c, PAWN)];
  int sc = 0;

  /* escudo de peoes */
  int shield = 0;
  for (int df = -1; df <= 1; df++) {
    int ff = f + df;
    if (ff < 0 || ff > 7) continue;
    /* peao amigo mais proximo A FRENTE do rei nessa coluna */
    U64 ahead = FILE_BB[ff] & own & FRONTSPAN[c][ks];
    if (!ahead) sc -= 18;                     /* coluna desguarnecida        */
    else {
      int sq = (c == WHITE) ? lsb(ahead) : (63 - __builtin_clzll(ahead));
      int rel = (c == WHITE) ? RANK_OF(sq) - RANK_OF(ks) : RANK_OF(ks) - RANK_OF(sq);
      if (rel == 1)      shield += 12;
      else if (rel == 2) shield += 6;
      else               shield -= 4;
    }
  }
  sc += shield;

  /* pressao inimiga na zona do rei */
  int atk = a->kzone_att[c ^ 1], cnt = a->kzone_cnt[c ^ 1];
  if (cnt >= 2) {
    int units = atk * cnt;
    sc -= (int)(units * 0.9f * st->aggression);
  } else sc -= atk / 2;

  /* colunas abertas apontando para o rei */
  U64 heavy = p->bb[PIECE(c ^ 1, ROOK)] | p->bb[PIECE(c ^ 1, QUEEN)];
  for (int df = -1; df <= 1; df++) {
    int ff = f + df;
    if (ff < 0 || ff > 7) continue;
    if ((FILE_BB[ff] & (p->bb[PIECE(WHITE, PAWN)] | p->bb[PIECE(BLACK, PAWN)])) == 0
        && (FILE_BB[ff] & heavy)) sc -= 22;
  }
  return sc;
}

static int threats_eval(const Position *p, const AttInfo *a, int c) {
  int sc = 0;
  U64 them = p->occ[c ^ 1] & ~p->bb[PIECE(c ^ 1, PAWN)];
  U64 weak = them & a->att[c] & ~a->att[c ^ 1];
  while (weak) {
    int s = pop_lsb(&weak);
    sc += 14 + MG_VAL[PC_TYPE(p->board[s])] / 16;
  }
  U64 by_pawn = them & a->pawn_att[c];
  sc += 22 * popcount(by_pawn);
  return sc;
}

/* ---------------------------------------------------------------- volatil. */
static float volatility(const Position *p, const AttInfo *a, int phase) {
  float s = 0.022f;
  int hang = 0;
  for (int c = 0; c < 2; c++) {
    U64 b = p->occ[c] & ~p->bb[PIECE(c, KING)];
    while (b) {
      int sq = pop_lsb(&b);
      if (!(a->att[c ^ 1] & BIT(sq))) continue;
      if ((a->att[c] & BIT(sq)) && MG_VAL[PC_TYPE(p->board[sq])] <= 340) {
        if (!(a->pawn_att[c ^ 1] & BIT(sq))) continue;
      }
      hang++;
    }
  }
  if (hang > 6) hang = 6;
  s += 0.030f * hang;

  int nq = popcount(p->bb[PIECE(WHITE, QUEEN)]) + popcount(p->bb[PIECE(BLACK, QUEEN)]);
  s += 0.022f * nq;

  if (in_check(p, p->stm)) s += 0.055f;

  for (int c = 0; c < 2; c++) {
    int ks = king_sq(p, c);
    if (ks == NO_SQ) continue;
    int exposed = popcount(attacks_queen(ks, p->occ[BOTH]) & ~p->occ[c]);
    if (exposed > 10) s += 0.004f * (exposed - 10);
    if (a->kzone_cnt[c ^ 1] >= 2) s += 0.018f * a->kzone_cnt[c ^ 1];
  }

  int npieces = popcount(p->occ[BOTH]);
  if (npieces < 12) s *= 0.55f + 0.045f * npieces;
  s *= (0.55f + 0.45f * phase / 256.0f);

  if (s < 0.010f) s = 0.010f;
  if (s > 0.330f) s = 0.330f;
  return s;
}

float cp_to_score(int cp, int phase) {
  float k = 235.0f + 0.40f * (float)phase;      /* finais convertem melhor   */
  float e = 1.0f / (1.0f + expf(-(float)cp / k));
  if (e < 0.0005f) e = 0.0005f;
  if (e > 0.9995f) e = 0.9995f;
  return e;
}

/* ------------------------------------------------------------------- main  */
int eval_cp_traced(const Position *p, const Style *st, EvalTrace *tr) {
  AttInfo a; collect(p, &a);
  int phase = game_phase(p);

  int mg = 0, eg = 0, mat = 0, pst = 0;
  for (int pc = 0; pc < 12; pc++) {
    U64 b = p->bb[pc];
    int sign = PC_COLOR(pc) == WHITE ? 1 : -1;
    while (b) {
      int s = pop_lsb(&b);
      mg += sign * MG_PST[pc][s];
      eg += sign * EG_PST[pc][s];
      mat += sign * MG_VAL[PC_TYPE(pc)];
      pst += sign * (MG_PST[pc][s] - MG_VAL[PC_TYPE(pc)]);
    }
  }
  mg = (int)(mg * (0.80f + 0.20f * st->materialism));
  eg = (int)(eg * (0.80f + 0.20f * st->materialism));

  if (popcount(p->bb[PIECE(WHITE, BISHOP)]) >= 2) { mg += 28; eg += 48; }
  if (popcount(p->bb[PIECE(BLACK, BISHOP)]) >= 2) { mg -= 28; eg -= 48; }

  int mob_mg = (int)((a.mob_mg[WHITE] - a.mob_mg[BLACK]) * st->activity);
  int mob_eg = (int)((a.mob_eg[WHITE] - a.mob_eg[BLACK]) * st->activity);
  mg += mob_mg; eg += mob_eg;

  int pw_eg, pb_eg;
  int pw_mg = pawn_eval(p, WHITE, &pw_eg);
  int pb_mg = pawn_eval(p, BLACK, &pb_eg);
  int pawns_mg = (int)((pw_mg - pb_mg) * st->structure);
  int pawns_eg = (int)((pw_eg - pb_eg) * st->structure);
  mg += pawns_mg; eg += pawns_eg;

  int kw = king_safety(p, &a, WHITE, st), kb = king_safety(p, &a, BLACK, st);
  mg += (kw - kb);
  eg += (kw - kb) / 5;

  int thr = threats_eval(p, &a, WHITE) - threats_eval(p, &a, BLACK);
  mg += thr; eg += thr / 2;

  /* torres em colunas abertas / 7a fileira */
  U64 allp = p->bb[PIECE(WHITE, PAWN)] | p->bb[PIECE(BLACK, PAWN)];
  int rookbonus = 0;
  for (int c = 0; c < 2; c++) {
    int sign = c == WHITE ? 1 : -1;
    U64 b = p->bb[PIECE(c, ROOK)];
    while (b) {
      int s = pop_lsb(&b);
      U64 fb = FILE_BB[FILE_OF(s)];
      if (!(fb & allp)) rookbonus += sign * 26;
      else if (!(fb & p->bb[PIECE(c, PAWN)])) rookbonus += sign * 12;
      int rel = c == WHITE ? RANK_OF(s) : 7 - RANK_OF(s);
      if (rel == 6) rookbonus += sign * 20;
    }
  }
  mg += rookbonus; eg += rookbonus / 2;

  /* espaco no centro */
  U64 center = (FILE_BB[2] | FILE_BB[3] | FILE_BB[4] | FILE_BB[5]);
  int spw = popcount(a.att[WHITE] & center & (RANK_BB[3] | RANK_BB[4] | RANK_BB[5]));
  int spb = popcount(a.att[BLACK] & center & (RANK_BB[2] | RANK_BB[3] | RANK_BB[4]));
  int space = (int)((spw - spb) * 3 * st->activity);
  mg += space;

  int cp = (mg * phase + eg * (256 - phase)) / 256;
  cp += (p->stm == WHITE ? 14 : -14);                 /* tempo               */

  if (tr) {
    tr->material = mat; tr->pst = pst;
    tr->mobility = (mob_mg * phase + mob_eg * (256 - phase)) / 256;
    tr->king_safety = kw - kb;
    tr->pawns = (pawns_mg * phase + pawns_eg * (256 - phase)) / 256;
    tr->threats = thr; tr->space = space;
    tr->total_cp = cp; tr->phase = phase;
    tr->hanging_us = 0; tr->hanging_them = 0;
    tr->checks_avail = 0;
    tr->sigma = volatility(p, &a, phase);
  }
  return cp;
}

int eval_cp(const Position *p, const Style *st) { return eval_cp_traced(p, st, NULL); }

Belief evaluate_traced(const Position *p, const Style *st, EvalTrace *tr) {
  EvalTrace local;
  if (!tr) tr = &local;
  int cp = eval_cp_traced(p, st, tr);
  Belief b;
  b.mu = cp_to_score(cp, tr->phase);

  /* material insuficiente / 50 lances puxam a crenca para o empate */
  if (is_draw_material(p)) { b.mu = 0.5f; b.sigma = 0.01f; return b; }
  if (p->halfmove > 60) {
    float t = (p->halfmove - 60) / 40.0f; if (t > 1) t = 1;
    b.mu = b.mu * (1 - t) + 0.5f * t;
  }
  /* bispos de cores opostas sem pesadas: forte tendencia a empate */
  int wb = popcount(p->bb[PIECE(WHITE, BISHOP)]), bb = popcount(p->bb[PIECE(BLACK, BISHOP)]);
  if (wb == 1 && bb == 1 && !p->bb[PIECE(WHITE, ROOK)] && !p->bb[PIECE(BLACK, ROOK)] &&
      !p->bb[PIECE(WHITE, QUEEN)] && !p->bb[PIECE(BLACK, QUEEN)] &&
      !p->bb[PIECE(WHITE, KNIGHT)] && !p->bb[PIECE(BLACK, KNIGHT)]) {
    U64 dark = 0xAA55AA55AA55AA55ULL;
    int wd = (p->bb[PIECE(WHITE, BISHOP)] & dark) != 0;
    int bd = (p->bb[PIECE(BLACK, BISHOP)] & dark) != 0;
    if (wd != bd) b.mu = 0.5f + (b.mu - 0.5f) * 0.42f;
  }
  b.sigma = tr->sigma;
  return b;
}

Belief evaluate(const Position *p, const Style *st) {
  return evaluate_traced(p, st, NULL);
}
