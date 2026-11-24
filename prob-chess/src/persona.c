/* ============================================================================
 *  persona.c -- A camada que torna a engine um JOGADOR, e nao uma funcao.
 *
 *   * personas: pesos de estilo + forca
 *   * livro de aberturas probabilistico (nunca a mesma partida duas vezes)
 *   * escolha final: entre lances praticamente equivalentes a engine decide
 *     por apetite de risco, naturalidade e temperamento -- nao por 0.001 de
 *     avaliacao. Quando um lance e objetivamente melhor, ela joga esse lance.
 *   * justificativa em linguagem natural a partir do traco da avaliacao.
 * ==========================================================================*/
#include "core.h"
#include <strings.h>

/* ------------------------------------------------------------- personas    */
static const Persona PERSONAS[] = {
  { "mestre", "Equilibrada e muito forte. O padrao.",
    { 1.00f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f }, 100, 0.85f },
  { "tatico", "Procura complicacoes, xeques e iniciativa.",
    { 1.40f, 0.92f, 1.10f, 0.90f, 1.35f, 1.30f, 0.80f }, 100, 0.70f },
  { "posicional", "Acumula pequenas vantagens, odeia risco inutil.",
    { 0.80f, 1.05f, 1.20f, 1.30f, 0.80f, 0.90f, 1.30f }, 100, 0.90f },
  { "romantico", "Xadrez do seculo XIX: ataque, sacrificio e iniciativa.",
    { 1.70f, 0.72f, 1.25f, 0.75f, 1.75f, 1.80f, 0.60f }, 100, 0.55f },
  { "solido", "Profilaxia primeiro. Empata com pretas sem reclamar.",
    { 0.75f, 1.12f, 0.95f, 1.25f, 0.62f, 0.75f, 1.40f }, 100, 0.95f },
  { "clube", "Jogador forte de clube (~1900). Erra de vez em quando.",
    { 1.10f, 1.00f, 0.95f, 0.90f, 1.10f, 1.40f, 0.90f },  72, 0.65f },
  { "amador", "Joga bem as ideias, falha nas tacticas (~1400).",
    { 1.15f, 1.05f, 0.85f, 0.80f, 1.20f, 1.70f, 0.80f },  45, 0.45f },
  { "iniciante", "Aprendendo. Ve uma jogada a frente, as vezes.",
    { 1.20f, 1.20f, 0.70f, 0.60f, 1.30f, 2.20f, 0.60f },  18, 0.25f },
};
static const int NPERSONA = (int)(sizeof(PERSONAS) / sizeof(PERSONAS[0]));

const Persona *persona_default(void) { return &PERSONAS[0]; }

const Persona *persona_find(const char *name) {
  for (int i = 0; i < NPERSONA; i++)
    if (!strcasecmp(name, PERSONAS[i].name)) return &PERSONAS[i];
  return NULL;
}
void persona_list(void) {
  printf("Personas disponiveis:\n");
  for (int i = 0; i < NPERSONA; i++)
    printf("  %-11s forca %3d  %s\n",
           PERSONAS[i].name, PERSONAS[i].strength, PERSONAS[i].desc);
}

/* ---------------------------------------------------------- livro          */
typedef struct { U64 key; Move m; int w; } BEnt;
static BEnt  *BOOK = NULL;
static int    BOOKN = 0, BOOKCAP = 0;

static void book_add(U64 key, Move m, int w) {
  for (int i = 0; i < BOOKN; i++)
    if (BOOK[i].key == key && BOOK[i].m == m) { BOOK[i].w += w; return; }
  if (BOOKN == BOOKCAP) {
    BOOKCAP = BOOKCAP ? BOOKCAP * 2 : 1024;
    BOOK = (BEnt *)realloc(BOOK, sizeof(BEnt) * (size_t)BOOKCAP);
  }
  BOOK[BOOKN].key = key; BOOK[BOOKN].m = m; BOOK[BOOKN].w = w; BOOKN++;
}

typedef struct { const char *line; int w; } BookLine;
static const BookLine LINES[] = {
 /* --- 1.e4 e5 ------------------------------------------------------------ */
 {"e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5 Bb3 d6 c3 O-O h3", 100},
 {"e4 e5 Nf3 Nc6 Bb5 a6 Bxc6 dxc6 O-O f6 d4 exd4 Nxd4 c5 Ne2", 55},
 {"e4 e5 Nf3 Nc6 Bb5 Nf6 O-O Nxe4 d4 Nd6 Bxc6 dxc6 dxe5 Nf5 Qxd8+ Kxd8", 70},
 {"e4 e5 Nf3 Nc6 Bc4 Bc5 c3 Nf6 d4 exd4 cxd4 Bb4+ Bd2 Bxd2+ Nbxd2 d5", 70},
 {"e4 e5 Nf3 Nc6 Bc4 Bc5 d3 Nf6 O-O d6 c3 a6 Bb3 Ba7 Re1 O-O", 80},
 {"e4 e5 Nf3 Nc6 Bc4 Nf6 Ng5 d5 exd5 Na5 Bb5+ c6 dxc6 bxc6 Be2 h6", 45},
 {"e4 e5 Nf3 Nc6 d4 exd4 Nxd4 Nf6 Nxc6 bxc6 e5 Qe7 Qe2 Nd5 c4 Ba6", 60},
 {"e4 e5 Nf3 Nf6 Nxe5 d6 Nf3 Nxe4 d4 d5 Bd3 Nc6 O-O Be7 c4 Nb4", 55},
 {"e4 e5 Nf3 Nc6 Nc3 Nf6 Bb5 Bb4 O-O O-O d3 d6 Bg5 Bxc3 bxc3 Qe7", 50},
 {"e4 e5 Nc3 Nf6 Bc4 Nxe4 Qh5 Nd6 Bb3 Nc6 Nb5 g6 Qf3 f5 Qd5 Qe7", 20},
 {"e4 e5 f4 exf4 Nf3 g5 h4 g4 Ne5 Nf6 d4 d6 Nd3 Nxe4 Bxf4 Qe7", 18},
 /* --- Siciliana ---------------------------------------------------------- */
 {"e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be3 e5 Nb3 Be6 f3 Be7", 95},
 {"e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Bg5 e6 f4 Be7 Qf3 Qc7", 55},
 {"e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 g6 c4 Nf6 Nc3 d6 Be2 Nxd4 Qxd4 Bg7", 60},
 {"e4 c5 Nf3 e6 d4 cxd4 Nxd4 Nc6 Nc3 Qc7 Be3 a6 Bd3 Nf6 O-O Be7", 65},
 {"e4 c5 Nf3 Nc6 Bb5 g6 Bxc6 dxc6 d3 Bg7 h3 Nf6 Nc3 O-O Be3 b6", 60},
 {"e4 c5 Nf3 d6 Bb5+ Bd7 Bxd7+ Qxd7 O-O Nc6 c3 Nf6 Re1 e6 d4 cxd4", 55},
 {"e4 c5 Nc3 Nc6 g3 g6 Bg2 Bg7 d3 d6 Be3 Rb8 Qd2 b5 Nge2 Nd4", 40},
 {"e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 g6 Be3 Bg7 f3 O-O Qd2 Nc6", 55},
 /* --- Francesa / Caro / outras --------------------------------------------*/
 {"e4 e6 d4 d5 Nc3 Bb4 e5 c5 a3 Bxc3+ bxc3 Ne7 Qg4 O-O Bd3 Nbc6", 55},
 {"e4 e6 d4 d5 Nd2 Nf6 e5 Nfd7 Bd3 c5 c3 Nc6 Ne2 cxd4 cxd4 f6", 55},
 {"e4 e6 d4 d5 Nc3 Nf6 Bg5 Be7 e5 Nfd7 Bxe7 Qxe7 f4 O-O Nf3 c5", 45},
 {"e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5 Ng3 Bg6 h4 h6 Nf3 Nd7 h5 Bh7", 60},
 {"e4 c6 d4 d5 e5 Bf5 Nf3 e6 Be2 c5 Be3 Nd7 O-O Ne7 c4 dxc4", 45},
 {"e4 d5 exd5 Qxd5 Nc3 Qa5 d4 Nf6 Nf3 c6 Bc4 Bf5 Bd2 e6 Nd5 Qd8", 35},
 {"e4 Nf6 e5 Nd5 d4 d6 Nf3 g6 Bc4 Nb6 Bb3 Bg7 Ng5 e6 Qf3 Qe7", 30},
 {"e4 d6 d4 Nf6 Nc3 g6 Nf3 Bg7 Be2 O-O O-O c6 a4 Nbd7 h3 e5", 35},
 {"e4 g6 d4 Bg7 Nc3 d6 f4 Nf6 Nf3 O-O Bd3 Na6 O-O c5 d5 Rb8", 25},
 /* --- 1.d4 --------------------------------------------------------------- */
 {"d4 d5 c4 e6 Nc3 Nf6 Bg5 Be7 e3 O-O Nf3 h6 Bh4 b6 Be2 Bb7", 85},
 {"d4 d5 c4 c6 Nf3 Nf6 Nc3 dxc4 a4 Bf5 e3 e6 Bxc4 Bb4 O-O Nbd7", 80},
 {"d4 d5 c4 dxc4 Nf3 Nf6 e3 e6 Bxc4 c5 O-O a6 a4 Nc6 Qe2 cxd4", 60},
 {"d4 d5 c4 e6 Nc3 c6 Nf3 Nf6 e3 Nbd7 Bd3 dxc4 Bxc4 b5 Bd3 Bb7", 60},
 {"d4 d5 c4 e6 Nc3 Nf6 cxd5 exd5 Bg5 Be7 e3 c6 Bd3 Nbd7 Qc2 O-O", 55},
 {"d4 Nf6 c4 e6 Nc3 Bb4 e3 O-O Bd3 d5 Nf3 c5 O-O Nc6 a3 Bxc3", 90},
 {"d4 Nf6 c4 e6 Nc3 Bb4 Qc2 O-O a3 Bxc3+ Qxc3 b6 Bg5 Bb7 f3 h6", 65},
 {"d4 Nf6 c4 e6 Nf3 b6 g3 Ba6 b3 Bb4+ Bd2 Be7 Bg2 c6 Bc3 d5", 65},
 {"d4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2 e5 O-O Nc6 d5 Ne7", 80},
 {"d4 Nf6 c4 g6 Nc3 d5 cxd5 Nxd5 e4 Nxc3 bxc3 Bg7 Nf3 c5 Rb1 O-O", 70},
 {"d4 Nf6 c4 g6 Nc3 Bg7 e4 d6 f3 O-O Be3 e5 Nge2 c6 Qd2 Nbd7", 45},
 {"d4 Nf6 Nf3 e6 c4 b6 g3 Bb7 Bg2 Be7 O-O O-O Nc3 Ne4 Qc2 Nxc3", 45},
 {"d4 d5 Nf3 Nf6 c4 e6 Nc3 c6 Bg5 h6 Bh4 dxc4 e4 g5 Bg3 b5", 30},
 {"d4 f5 g3 Nf6 Bg2 g6 Nf3 Bg7 O-O O-O c4 d6 Nc3 Qe8 Re1 e5", 25},
 {"d4 Nf6 c4 c5 d5 b5 cxb5 a6 bxa6 g6 Nc3 Bxa6 g3 d6 Bg2 Bg7", 25},
 {"d4 d5 c4 Nc6 Nf3 Bg4 cxd5 Bxf3 gxf3 Qxd5 e3 e5 Nc3 Bb4 Bd2 Bxc3", 18},
 {"d4 e6 Nf3 Nf6 c4 Bb4+ Bd2 Qe7 g3 Nc6 Bg2 Bxd2+ Nbxd2 d6 O-O O-O", 30},
 /* --- Inglesa / Reti ----------------------------------------------------- */
 {"c4 e5 Nc3 Nf6 Nf3 Nc6 g3 d5 cxd5 Nxd5 Bg2 Nb6 O-O Be7 a3 O-O", 55},
 {"c4 c5 Nf3 Nf6 Nc3 Nc6 g3 g6 Bg2 Bg7 O-O O-O d4 cxd4 Nxd4 Ng4", 45},
 {"c4 Nf6 Nc3 e6 Nf3 d5 d4 Be7 Bg5 h6 Bh4 O-O e3 b6", 40},
 {"Nf3 d5 g3 Nf6 Bg2 e6 O-O Be7 d3 O-O Nbd2 c5 e4 Nc6 Re1 b5", 45},
 {"Nf3 Nf6 c4 g6 Nc3 d5 cxd5 Nxd5 g3 Bg7 Bg2 Nb6 O-O O-O", 35},
 {"c4 e6 Nc3 d5 d4 Nf6 Nf3 Be7 Bg5 h6 Bh4 O-O e3 Nbd7 Rc1 c6", 40},
};
static const int NLINES = (int)(sizeof(LINES) / sizeof(LINES[0]));

static int BOOK_BAD = 0;

void book_init(void) {
  static int done = 0; if (done) return; done = 1;
  for (int i = 0; i < NLINES; i++) {
    Position p; pos_startpos(&p);
    char buf[512];
    snprintf(buf, sizeof(buf), "%s", LINES[i].line);
    char *save = NULL, *tok;
    for (tok = strtok_r(buf, " ", &save); tok; tok = strtok_r(NULL, " ", &save)) {
      Move m = parse_move(&p, tok);
      if (m == MOVE_NONE) { BOOK_BAD++; break; }
      book_add(p.key, m, LINES[i].w);
      if (!do_move(&p, m)) { BOOK_BAD++; break; }
    }
  }
}
int book_problems(void) { return BOOK_BAD; }
int book_size(void) { return BOOKN; }

Move book_pick(const Position *p, float weight, uint64_t *rng, char *out_name) {
  if (out_name) out_name[0] = 0;
  if (weight <= 0.0f || p->fullmove > 16) return MOVE_NONE;
  if (rng_unit(rng) > (double)weight) return MOVE_NONE;
  Move cand[32]; int w[32], n = 0, tot = 0;
  for (int i = 0; i < BOOKN && n < 32; i++)
    if (BOOK[i].key == p->key) { cand[n] = BOOK[i].m; w[n] = BOOK[i].w; tot += w[n]; n++; }
  if (!n) return MOVE_NONE;
  int r = (int)(rng_unit(rng) * tot), acc = 0;
  for (int i = 0; i < n; i++) {
    acc += w[i];
    if (r < acc) {
      if (!move_is_legal(p, cand[i])) return MOVE_NONE;
      if (out_name) snprintf(out_name, 32, "livro (%d%%)", w[i] * 100 / tot);
      return cand[i];
    }
  }
  return cand[0];
}

/* ------------------------------------------------- justificativa textual   */
static void explain(const Position *p, Move m, const RootMove *chosen,
                    const RootMove *alt, int has_alt, const Style *st,
                    float root_sigma, long nodes, char *out, int cap)
{
  EvalTrace a, b;
  Position q = *p;
  evaluate_traced(p, st, &a);
  int us = p->stm;
  int gave_check = 0, cap_see = 0, is_castle = 0;
  int fl = M_FLAG(m);
  is_castle = (fl == MF_KCASTLE || fl == MF_QCASTLE);
  if (M_IS_CAP(m) || fl == MF_EP) cap_see = see(p, m);
  if (do_move(&q, m)) {
    gave_check = in_check(&q, q.stm);
    evaluate_traced(&q, st, &b);
  } else { b = a; }

  int sgn = (us == WHITE) ? 1 : -1;
  int d_mob  = sgn * (b.mobility - a.mobility);
  int d_king = sgn * (b.king_safety - a.king_safety);
  int d_pawn = sgn * (b.pawns - a.pawns);
  int d_thr  = sgn * (b.threats - a.threats);

  const char *ph[4]; int np = 0;
  if (chosen->proven == 1 && chosen->mate_in)
    ph[np++] = "forca o mate";
  if (cap_see > 60)                 ph[np++] = "ganha material";
  else if (cap_see < -40)           ph[np++] = "e um sacrificio calculado";
  if (gave_check && np < 3)         ph[np++] = "da xeque e nao deixa respirar";
  if (is_castle && np < 3)          ph[np++] = "poe o rei a salvo e liga as torres";
  if (d_king < -25 && np < 3)       ph[np++] = "aperta o cerco ao rei adversario";
  if (d_thr > 25 && np < 3)         ph[np++] = "cria uma ameaca concreta";
  if (d_mob > 18 && np < 3)         ph[np++] = "ganha espaco e atividade";
  if (d_pawn > 15 && np < 3)        ph[np++] = "melhora a estrutura de peoes";
  if (M_IS_PROMO(m) && np < 3)      ph[np++] = "promove";
  if (np == 0) {
    if (root_sigma > 0.09f)         ph[np++] = "mantem a tensao sem se comprometer";
    else if (st->risk < 0.9f)       ph[np++] = "simplifica e segura a vantagem";
    else                            ph[np++] = "melhora a pior peca e espera";
  }

  char tail[256]; tail[0] = 0;
  if (has_alt) {
    snprintf(tail, sizeof(tail), " Considerei %s (%.0f%%)%s.",
             alt->san, alt->mu * 100.0,
             (chosen->mu - alt->mu) < 0.012f ? ", quase igual" : "");
  }

  char mate[48]; mate[0] = 0;
  if (chosen->proven == 1 && chosen->mate_in)
    snprintf(mate, sizeof(mate), " Mate em %d.", chosen->mate_in);
  else if (chosen->proven == -1)
    snprintf(mate, sizeof(mate), " Estou perdido a forca.");

  char why[256];
  if (np == 1) snprintf(why, sizeof(why), "%s", ph[0]);
  else if (np == 2) snprintf(why, sizeof(why), "%s e %s", ph[0], ph[1]);
  else snprintf(why, sizeof(why), "%s, %s e %s", ph[0], ph[1], ph[2]);

  snprintf(out, (size_t)cap,
           "%s -- %s. Minhas chances: %.0f%% (+-%.0f). %ld nos.%s%s",
           chosen->san, why, chosen->mu * 100.0, chosen->sigma * 100.0,
           nodes, mate, tail);
}

/* --------------------------------------------------- escolha humanizada    */
Move humanize_choice(const SearchResult *res, const Position *p,
                     const Style *st, int strength, uint64_t *rng,
                     char *reason_out, int cap)
{
  if (res->nroots <= 0) return MOVE_NONE;
  const RootMove *best = &res->roots[0];

  /* mate forcado: nunca brincar com isso */
  if (best->proven == 1) {
    if (reason_out) explain(p, best->move, best, &res->roots[1],
                            res->nroots > 1, st, res->root_sigma,
                            res->nodes, reason_out, cap);
    return best->move;
  }

  float s = (float)strength / 100.0f;

  /* apetite por variancia: quem esta pior procura complicar, quem esta
   * melhor procura simplificar. Modulado pelo temperamento.                */
  float lambda = (st->risk - 1.0f) * 0.55f + (0.5f - best->mu) * 0.75f;
  if (lambda >  0.9f) lambda =  0.9f;
  if (lambda < -0.9f) lambda = -0.9f;

  /* janela: so aceita trocar de lance se o custo objetivo for pequeno      */
  float window = 0.010f + 0.055f * (1.0f - s) * (1.0f - s)
               + 0.008f * (st->creativity - 1.0f);
  if (window < 0.004f) window = 0.004f;

  float tau = 0.0045f * st->creativity + 0.030f * (1.0f - s);

  int idx[MAX_MOVES]; float eff[MAX_MOVES]; int n = 0;
  int any_safe = 0;
  for (int i = 0; i < res->nroots; i++) if (res->roots[i].proven != -1) any_safe = 1;

  for (int i = 0; i < res->nroots; i++) {
    const RootMove *r = &res->roots[i];
    if (any_safe && r->proven == -1) continue;
    if (best->mu - r->mu > window) continue;
    float e = r->mu + lambda * r->sigma + 0.004f * r->prior;
    idx[n] = i; eff[n] = e; n++;
    if (n >= 12) break;
  }
  if (n == 0) { idx[0] = 0; eff[0] = best->mu; n = 1; }

  float mx = -1e30f;
  for (int i = 0; i < n; i++) if (eff[i] > mx) mx = eff[i];
  double sum = 0, wgt[12];
  for (int i = 0; i < n; i++) { wgt[i] = exp((eff[i] - mx) / tau); sum += wgt[i]; }
  double r = rng_unit(rng) * sum, acc = 0;
  int sel = idx[n - 1];
  for (int i = 0; i < n; i++) { acc += wgt[i]; if (r < acc) { sel = idx[i]; break; } }

  const RootMove *ch = &res->roots[sel];
  if (reason_out) {
    int alt = (sel == 0) ? (res->nroots > 1 ? 1 : 0) : 0;
    explain(p, ch->move, ch, &res->roots[alt], res->nroots > 1,
            st, res->root_sigma, res->nodes, reason_out, cap);
  }
  return ch->move;
}
