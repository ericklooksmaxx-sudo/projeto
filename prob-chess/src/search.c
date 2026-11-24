/* ============================================================================
 *  search.c -- Busca por amostragem de crencas (Thompson Tree Search).
 *
 *  NAO ha alfa-beta, janelas, poda de nulo nem quiescencia. O algoritmo e:
 *
 *   1. DESCIDA  : em cada no, sorteia-se um valor da posterior de cada lance
 *                 ( v_i ~ N(mu_i, res_i^2) ) e desce-se pelo maior sorteio
 *                 do ponto de vista de quem joga. Isso e Thompson Sampling:
 *                 um lance so e explorado na proporcao da probabilidade de
 *                 ele ser realmente o melhor.
 *   2. EXPANSAO : gera os lances legais, atribui a cada um um PRIOR (modelo
 *                 de atencao humana: o quanto um jogador forte sequer
 *                 cogitaria o lance) e avalia cada filho como crenca.
 *   3. BACKUP   : o valor do pai NAO e o max dos filhos. E a media dos filhos
 *                 ponderada pela probabilidade de cada um ser o melhor
 *                 (minimax probabilistico, estilo BPIP). Quando a incerteza
 *                 vai a zero, isso converge exatamente para o minimax.
 *   4. SOLVER   : mates e empates forcados sao propagados de forma EXATA,
 *                 entao a engine nao "quase" ve um mate: ela prova o mate.
 *
 *  A incerteza encolhe 10% por nivel de arvore (gamma). E por isso que
 *  procurar mais fundo deixa a engine mais confiante, e nao so mais lenta.
 * ==========================================================================*/
#include "core.h"

#ifndef GAMMA
#define GAMMA        0.90f
#endif
#ifndef BETA
#define BETA         0.60f
#endif    /* reducao de incerteza por nivel             */
#define T_SCALE      0.85f    /* temperatura do backup / incerteza media    */
#define RES_FLOOR    0.0035f
#define EXPLORE_C    0.030f   /* garante exploracao assintotica             */
#define PRIOR_OPT    0.055f   /* otimismo inicial proporcional ao prior     */
#define PRIOR_TEMP   1.00f

static const int PVAL[6] = { 100, 325, 340, 500, 960, 20000 };

typedef struct {
  Move     move;
  int32_t  first;        /* indice do primeiro filho (-1 = folha)           */
  int16_t  n;            /* nro de filhos (-1 = nao expandido)              */
  uint8_t  stm;          /* lado a jogar NESTE no                           */
  uint8_t  solved;       /* 1 = valor provado                               */
  uint32_t visits;
  float    mu;           /* crenca: pontuacao esperada das BRANCAS [0,1]    */
  float    res;          /* incerteza residual                              */
  float    prior;
  float    sval;         /* valor provado                                   */
  int16_t  mate;         /* lances ate o mate (0 = nenhum)                  */
} Node;

static Node  *POOL = NULL;
static long   POOL_CAP = 0;
static long   POOL_USED = 0;

void search_init(long cap) {
  if (POOL) free(POOL);
  if (cap < 4096) cap = 4096;
  POOL_CAP = cap;
  POOL = (Node *)malloc(sizeof(Node) * (size_t)cap);
  POOL_USED = 0;
}
void search_free(void) { free(POOL); POOL = NULL; POOL_CAP = POOL_USED = 0; }

static int new_node(Move m, int stm, float mu, float res, float prior) {
  if (POOL_USED >= POOL_CAP) return -1;
  Node *n = &POOL[POOL_USED];
  n->move = m; n->first = -1; n->n = -1; n->stm = (uint8_t)stm;
  n->solved = 0; n->visits = 0; n->mu = mu; n->res = res;
  n->prior = prior; n->sval = 0.0f; n->mate = 0;
  return (int)POOL_USED++;
}

/* ------------------------------------------------- modelo de atencao       */
static int least_attacker_val(const Position *p, int sq, int by) {
  U64 a = attackers_to(p, sq, by, p->occ[BOTH]);
  if (!a) return 0;
  for (int t = PAWN; t <= KING; t++)
    if (a & p->bb[PIECE(by, t)]) return PVAL[t];
  return 0;
}

static int is_threatened(const Position *p, int sq) {
  int pc = p->board[sq];
  if (pc == NO_PIECE) return 0;
  int c = PC_COLOR(pc), v = PVAL[PC_TYPE(pc)];
  int la = least_attacker_val(p, sq, c ^ 1);
  if (!la) return 0;
  if (la < v) return 1;
  int na = popcount(attackers_to(p, sq, c ^ 1, p->occ[BOTH]));
  int nd = popcount(attackers_to(p, sq, c,     p->occ[BOTH]));
  return na > nd;
}

/* quanto um humano forte sequer COGITARIA este lance (log-odds, pre-softmax) */
static float attention_score(const Position *p, Move m, const Style *st,
                             int gives_check, int was_threatened, float vgain)
{
  float s = 7.0f * vgain;                 /* o ganho de crenca e o maior sinal */
  int from = M_FROM(m), to = M_TO(m), fl = M_FLAG(m);
  int pt = PC_TYPE(p->board[from]);
  int us = p->stm;

  if (M_IS_CAP(m) || fl == MF_EP) {
    int sv = see(p, m);
    if (sv > 0)      s += 1.9f + (float)sv / 380.0f;
    else if (sv == 0) s += 0.75f;
    else              s += -1.30f + (float)sv / 900.0f;
  }
  if (gives_check) s += 1.05f * (0.7f + 0.6f * st->aggression);
  if (M_IS_PROMO(m)) s += (M_PROMO_PT(m) == QUEEN) ? 2.4f : 0.2f;
  if (fl == MF_KCASTLE || fl == MF_QCASTLE) s += 0.95f;
  if (was_threatened) s += 1.45f;

  /* nao colocar peca em casa batida por peao inimigo */
  if (pt != PAWN && pt != KING) {
    U64 pw = p->bb[PIECE(us ^ 1, PAWN)];
    U64 pa = (us ^ 1) == WHITE
           ? ((pw & ~FILE_BB[0]) << 7) | ((pw & ~FILE_BB[7]) << 9)
           : ((pw & ~FILE_BB[0]) >> 9) | ((pw & ~FILE_BB[7]) >> 7);
    if (pa & BIT(to)) s -= 1.15f;
  }
  /* desenvolvimento e centro na abertura */
  int phase = game_phase(p);
  if (phase > 170) {
    int home = (us == WHITE) ? 0 : 7;
    if ((pt == KNIGHT || pt == BISHOP) && RANK_OF(from) == home) s += 0.55f;
    if (pt == QUEEN && RANK_OF(from) == home) s -= 0.45f;
    if (pt == PAWN && (FILE_OF(to) == 3 || FILE_OF(to) == 4)) s += 0.40f;
    if (pt == ROOK && RANK_OF(from) == home && (FILE_OF(from) == 0 || FILE_OF(from) == 7)
        && FILE_OF(to) != FILE_OF(from)) s += 0.15f;
    /* mover a mesma peca duas vezes e menos natural; aproximado pelo PST */
  }
  /* atividade: avancar em direcao ao rei inimigo quando agressivo */
  if (st->aggression > 1.0f && pt != KING) {
    int eks = king_sq(p, us ^ 1);
    if (eks != NO_SQ) {
      int df = abs(FILE_OF(to) - FILE_OF(eks)) + abs(RANK_OF(to) - RANK_OF(eks));
      int d0 = abs(FILE_OF(from) - FILE_OF(eks)) + abs(RANK_OF(from) - RANK_OF(eks));
      if (df < d0) s += 0.18f * (st->aggression - 1.0f) * 4.0f;
    }
  }
  return s;
}

/* ------------------------------------------------------------ terminalidade */
static int terminal_value(Position *p, int nmoves, float *out) {
  if (nmoves == 0) {
    if (in_check(p, p->stm)) { *out = (p->stm == WHITE) ? 0.0f : 1.0f; return 2; }
    *out = 0.5f; return 1;                                 /* afogado        */
  }
  if (p->halfmove >= 100) { *out = 0.5f; return 1; }
  if (is_draw_material(p)) { *out = 0.5f; return 1; }
  if (is_repetition(p))    { *out = 0.5f; return 1; }
  return 0;
}

/* ---------------------------------------------------------------- backup    */
static void refresh(int i) {
  Node *p = &POOL[i];
  int c0 = p->first, n = p->n;
  if (n <= 0) return;
  int sign = (p->stm == WHITE) ? 1 : -1;
  float win = (p->stm == WHITE) ? 1.0f : 0.0f;

  /* --- solver exato --------------------------------------------------- */
  int all_solved = 1, has = 0;
  float best_s = 0.0f; int best_mate = 0;
  for (int k = 0; k < n; k++) {
    Node *c = &POOL[c0 + k];
    if (!c->solved) { all_solved = 0; continue; }
    float v = c->sval;
    if (!has || sign * (v - best_s) > 0.0f) {
      best_s = v; best_mate = c->mate; has = 1;
    } else if (v == best_s && c->mate && (!best_mate || c->mate + 1 < best_mate + 1)) {
      if (!best_mate || c->mate < best_mate) best_mate = c->mate;
    }
  }
  if (has && best_s == win) {                 /* vitoria forcada: prova ja   */
    p->solved = 1; p->sval = win; p->mu = win; p->res = 0.0f;
    p->mate = (int16_t)(best_mate + 1);
    return;
  }
  if (all_solved) {
    p->solved = 1; p->sval = best_s; p->mu = best_s; p->res = 0.0f;
    p->mate = (int16_t)(best_mate ? best_mate + 1 : 0);
    return;
  }

  /* --- minimax probabilistico (aproximacao de Clark) -------------------
   * O valor do pai nao e max(mu_i): e E[ max_i X_i ] com X_i ~ N(mu_i,r_i).
   * Isso e estritamente maior que o max, e a diferenca e exatamente "a
   * chance de haver aqui algo melhor do que eu ja entendi". Dobrando os
   * filhos dois a dois pela formula de Clark obtem-se media E variancia,
   * e quando as incertezas vao a zero isso vira o minimax exato.
   * BETA controla quanto desse otimismo a engine aceita.
   */
  int kbest = 0; float zmax = -1e30f;
  for (int k = 0; k < n; k++) {
    float z = sign * POOL[c0 + k].mu;
    if (z > zmax) { zmax = z; kbest = k; }
  }
  float m = zmax, v = POOL[c0 + kbest].res * POOL[c0 + kbest].res;
  for (int k = 0; k < n; k++) {
    if (k == kbest) continue;
    Node *c = &POOL[c0 + k];
    float z = sign * c->mu, r2 = c->res * c->res;
    float th2 = v + r2;
    if (th2 < 1e-12f) continue;
    float th = sqrtf(th2);
    float d = (m - z) / th;
    if (d > 4.5f) continue;                  /* contribuicao desprezivel   */
    float Phi = 1.0f / (1.0f + expf(-1.702f * d));
    float phi = 0.39894228f * expf(-0.5f * d * d);
    float nm = m * Phi + z * (1.0f - Phi) + th * phi;
    float ne2 = (m * m + v) * Phi + (z * z + r2) * (1.0f - Phi)
              + (m + z) * th * phi;
    v = ne2 - nm * nm;
    if (v < 0.0f) v = 0.0f;
    m = nm;
  }
  m = zmax + BETA * (m - zmax);              /* otimismo parcial           */
  p->mu = sign * m;
  if (p->mu < 0.0005f) p->mu = 0.0005f;
  if (p->mu > 0.9995f) p->mu = 0.9995f;
  p->res = GAMMA * sqrtf(v);
  if (p->res < RES_FLOOR) p->res = RES_FLOOR;
}

/* --------------------------------------------------------------- expansao   */
static int expand(int idx, Position *p, const Style *st, float noise,
                  uint64_t *rng)
{
  MoveList pl; gen_pseudo(p, &pl);
  Move  mv[MAX_MOVES];
  float cmu[MAX_MOVES], cres[MAX_MOVES], sc[MAX_MOVES];
  int   nm = 0;

  float parent_mu = POOL[idx].mu;
  int sign = (p->stm == WHITE) ? 1 : -1;

  for (int i = 0; i < pl.n; i++) {
    Move m = pl.m[i];
    int thr = is_threatened(p, M_FROM(m));
    int fl_ep = (M_FLAG(m) == MF_EP);
    /* SEE tem de ser medido ANTES de aplicar o lance */
    int msee = (M_IS_CAP(m) || fl_ep) ? see(p, m) : 0;
    if (!do_move(p, m)) continue;
    float v; int chk = in_check(p, p->stm);
    MoveList rep; gen_legal(p, &rep);
    int t = terminal_value(p, rep.n, &v);
    Belief b;
    if (t) { b.mu = v; b.sigma = 0.0f; }
    else {
      b = evaluate(p, st);
      if (noise > 0.0f) {
        b.mu += (float)(rng_normal(rng) * noise);
        if (b.mu < 0.001f) b.mu = 0.001f;
        if (b.mu > 0.999f) b.mu = 0.999f;
      }
    }
    int sacrifice = (M_IS_CAP(m) || fl_ep) && msee < -60;
    undo_move(p);

    /* --- epistemologia: onde a avaliacao estatica MENTE ------------------
     * Um xeque ou um sacrificio sao exatamente as posicoes em que o valor
     * estatico e menos confiavel: a sequencia forcada pode inverter tudo.
     * Aumentar a incerteza (e nao o valor) faz o Thompson Sampling ir
     * investigar essas linhas, sem nunca mentir sobre o valor delas.      */
    if (!t) {
      if (chk)       b.sigma *= 2.7f;
      if (sacrifice) b.sigma *= 2.3f;
      if (b.sigma > 0.45f) b.sigma = 0.45f;
    }

    mv[nm] = m; cmu[nm] = b.mu; cres[nm] = b.sigma;
    sc[nm] = attention_score(p, m, st, chk, thr, sign * (b.mu - parent_mu));
    if (t == 2) sc[nm] += 6.0f;                 /* mate imediato: olhe isso  */
    nm++;
  }

  if (nm == 0) { POOL[idx].n = 0; POOL[idx].first = -1; return 0; }
  if (POOL_USED + nm > POOL_CAP) return -1;     /* memoria esgotada          */

  /* softmax -> prior */
  float mx = -1e30f;
  for (int i = 0; i < nm; i++) if (sc[i] > mx) mx = sc[i];
  float sum = 0.0f;
  for (int i = 0; i < nm; i++) { sc[i] = expf((sc[i] - mx) / PRIOR_TEMP); sum += sc[i]; }

  int first = -1;
  for (int i = 0; i < nm; i++) {
    float pr = sc[i] / sum;
    /* otimismo inicial: o que um humano cogitaria ganha o beneficio da duvida */
    float mu0 = cmu[i] + sign * PRIOR_OPT * pr;
    if (mu0 < 0.0005f) mu0 = 0.0005f;
    if (mu0 > 0.9995f) mu0 = 0.9995f;
    int id = new_node(mv[i], p->stm ^ 1, mu0, cres[i], pr);
    if (id < 0) return -1;
    if (first < 0) first = id;
    if (cres[i] == 0.0f) {                      /* filho terminal: provado   */
      POOL[id].solved = 1; POOL[id].sval = cmu[i]; POOL[id].mu = cmu[i];
      POOL[id].res = 0.0f;
      POOL[id].mate = (cmu[i] == 0.5f) ? 0 : 0;
      POOL[id].n = 0; POOL[id].first = -1;
    }
  }
  POOL[idx].first = first;
  POOL[idx].n = (int16_t)nm;
  refresh(idx);
  return nm;
}

/* --------------------------------------------------------------- selecao    */
static int pick_child(int idx, uint64_t *rng) {
  Node *p = &POOL[idx];
  int c0 = p->first, n = p->n;
  int sign = (p->stm == WHITE) ? 1 : -1;
  int best = -1; float bestv = -1e30f;
  int best_any = -1; float bestv_any = -1e30f;

  for (int k = 0; k < n; k++) {
    Node *c = &POOL[c0 + k];
    float r = c->res + EXPLORE_C / (1.0f + 0.5f * sqrtf((float)c->visits));
    if (c->solved) r = 0.0f;
    float v = sign * (c->mu + (float)(rng_normal(rng) * r));
    if (v > bestv_any) { bestv_any = v; best_any = c0 + k; }
    if (!c->solved && v > bestv) { bestv = v; best = c0 + k; }
  }
  return best >= 0 ? best : best_any;
}

/* --------------------------------------------------------------- PV         */
static void build_pv(int root, Position *p, char *out, int cap) {
  int i = root, used = 0, made = 0;
  out[0] = 0;
  while (POOL[i].n > 0 && made < 24) {
    int c0 = POOL[i].first, n = POOL[i].n, best = -1;
    int sign = (POOL[i].stm == WHITE) ? 1 : -1;
    /* nos pouco visitados nao tem estatistica confiavel: ali a PV segue a
     * crenca (mu), nao a contagem de visitas, senao vira ruido.            */
    uint32_t maxv = 0;
    for (int k = 0; k < n; k++) if (POOL[c0 + k].visits > maxv) maxv = POOL[c0 + k].visits;
    int use_visits = (maxv >= 8);
    double bv = -1e30;
    for (int k = 0; k < n; k++) {
      Node *c = &POOL[c0 + k];
      double score = use_visits ? (double)c->visits + sign * c->mu
                                : sign * c->mu;
      if (c->solved && c->sval == (POOL[i].stm == WHITE ? 1.0f : 0.0f))
        score += 1e18;
      if (c->solved && c->sval == (POOL[i].stm == WHITE ? 0.0f : 1.0f))
        score -= 1e18;
      if (score > bv) { bv = score; best = c0 + k; }
    }
    if (best < 0) break;
    char san[12]; move_to_san(p, POOL[best].move, san);
    int len = (int)strlen(san);
    if (used + len + 2 >= cap) break;
    if (used) out[used++] = ' ';
    memcpy(out + used, san, (size_t)len); used += len; out[used] = 0;
    if (!do_move(p, POOL[best].move)) break;
    made++;
    i = best;
  }
  while (made--) undo_move(p);
}

/* --------------------------------------------------------------- think      */
void think(Position *p, const Style *st, const SearchLimits *lim,
           SearchResult *res)
{
  memset(res, 0, sizeof(*res));
  POOL_USED = 0;
  uint64_t rng = lim->seed ? lim->seed : 0xC0FFEE123456789ULL;
  double t0 = now_ms();

  /* ruido de avaliacao para forcas reduzidas */
  float noise = 0.0f;
  if (lim->strength < 100) {
    float d = (100.0f - (float)lim->strength) / 100.0f;
    noise = 0.012f + 0.16f * d * d;
  }

  MoveList legal; gen_legal(p, &legal);
  if (legal.n == 0) { res->best = MOVE_NONE; return; }

  Belief rb = evaluate(p, st);
  int root = new_node(MOVE_NONE, p->stm, rb.mu, rb.sigma, 1.0f);
  if (expand(root, p, st, noise, &rng) <= 0) {
    res->best = legal.m[0]; res->nroots = 0; return;
  }

  if (legal.n == 1) {
    Node *c = &POOL[POOL[root].first];
    float v = c->solved ? c->sval : c->mu;        /* valor provado tem prioridade */
    res->best = legal.m[0];
    res->nroots = 1;
    res->roots[0].move = legal.m[0];
    res->roots[0].mu = (p->stm == WHITE) ? v : 1.0f - v;
    res->roots[0].sigma = c->res;
    res->roots[0].visits = 1;
    res->roots[0].prior = 1.0f;
    if (c->solved && c->sval != 0.5f)
      res->roots[0].proven = ((c->sval == 1.0f) == (p->stm == WHITE)) ? 1 : -1;
    move_to_san(p, legal.m[0], res->roots[0].san);
    res->best_mu = res->roots[0].mu;
    snprintf(res->reason, sizeof(res->reason), "Lance unico.");
    res->elapsed_ms = now_ms() - t0;
    return;
  }

  int path[MAX_PLY];
  long iters = 0, nodes = 0;
  int maxdepth = 0;
  double deadline = t0 + lim->time_ms;

  while (1) {
    if ((iters & 31) == 0) {
      if (lim->time_ms > 0 && now_ms() >= deadline) break;
      if (lim->max_nodes > 0 && nodes >= lim->max_nodes) break;
      if (POOL_USED + 300 >= POOL_CAP) break;
      if (POOL[root].solved) break;              /* resultado provado       */
    }
    iters++;

    int i = root, depth = 0, made = 0;
    path[depth++] = root;
    while (POOL[i].n > 0) {
      int c = pick_child(i, &rng);
      if (c < 0) break;
      if (!do_move(p, POOL[c].move)) break;      /* nunca deve ocorrer      */
      made++;
      i = c;
      path[depth++] = i;
      if (depth >= MAX_PLY - 2) break;
    }
    if (depth > maxdepth) maxdepth = depth;

    if (POOL[i].n < 0) {                         /* folha nao expandida     */
      MoveList l; gen_legal(p, &l);
      float v;
      int t = terminal_value(p, l.n, &v);
      if (t) {
        POOL[i].solved = 1; POOL[i].sval = v; POOL[i].mu = v; POOL[i].res = 0;
        POOL[i].n = 0; POOL[i].first = -1;
        POOL[i].mate = 0;
      } else {
        int r = expand(i, p, st, noise, &rng);
        if (r < 0) { while (made--) undo_move(p); break; }
        nodes += r;
      }
    }

    for (int k = depth - 1; k >= 0; k--) {
      POOL[path[k]].visits++;
      if (POOL[path[k]].n > 0) refresh(path[k]);
    }
    while (made--) undo_move(p);
  }

  /* ---------------------------------------------------- resultado da raiz  */
  int c0 = POOL[root].first, n = POOL[root].n;
  int sign = (p->stm == WHITE) ? 1 : -1;
  res->nroots = n;
  for (int k = 0; k < n; k++) {
    Node *c = &POOL[c0 + k];
    RootMove *r = &res->roots[k];
    r->move = c->move;
    r->mu = (p->stm == WHITE) ? c->mu : 1.0f - c->mu;
    r->sigma = c->res;
    r->prior = c->prior;
    r->visits = (long)c->visits;
    r->proven = 0; r->mate_in = 0;
    if (c->solved) {
      if (c->sval == 0.5f) r->proven = 0;
      else if ((c->sval == 1.0f) == (p->stm == WHITE)) { r->proven = 1; r->mate_in = (c->mate + 1) / 2 + ((c->mate + 1) % 2); }
      else { r->proven = -1; r->mate_in = (c->mate + 1) / 2 + ((c->mate + 1) % 2); }
      r->mu = (p->stm == WHITE) ? c->sval : 1.0f - c->sval;
    }
    move_to_san(p, c->move, r->san);
    if (do_move(p, c->move)) {
      build_pv(c0 + k, p, r->pv, (int)sizeof(r->pv));
      undo_move(p);
    }
  }
  /* ordena: provado-ganha > mu > visitas */
  for (int a = 0; a < n; a++)
    for (int b = a + 1; b < n; b++) {
      RootMove *x = &res->roots[a], *y = &res->roots[b];
      int sw = 0;
      if (y->proven > x->proven) sw = 1;
      else if (y->proven == x->proven) {
        if (x->proven == 1) sw = (y->mate_in < x->mate_in);
        else if (y->mu > x->mu + 1e-6f) sw = 1;
        else if (fabsf(y->mu - x->mu) <= 1e-6f && y->visits > x->visits) sw = 1;
      }
      if (sw) { RootMove t = *x; *x = *y; *y = t; }
    }

  res->best = res->nroots ? res->roots[0].move : legal.m[0];
  res->best_mu = res->nroots ? res->roots[0].mu : 0.5f;
  res->root_sigma = POOL[root].res;
  res->nodes = nodes;
  res->depth_reached = maxdepth;
  res->elapsed_ms = now_ms() - t0;
  (void)sign;
}
