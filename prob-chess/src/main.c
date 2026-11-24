/* ============================================================================
 *  main.c -- interface de linha de comando e protocolo UCI.
 * ==========================================================================*/
#include "core.h"
#include <strings.h>

int book_problems(void);
int book_size(void);

typedef struct {
  char        fen[128];
  char        moves[4096];
  double      secs;
  long        nodes;
  const Persona *per;
  uint64_t    seed;
  int         verbose;
  int         depth_hint;
  long        pool;
} Opts;

static void defaults(Opts *o) {
  strcpy(o->fen, "startpos");
  o->moves[0] = 0;
  o->secs = 3.0;
  o->nodes = 0;
  o->per = persona_default();
  o->seed = (uint64_t)now_ms() ^ 0x9E3779B97F4A7C15ULL;
  o->verbose = 0;
  o->depth_hint = 0;
  o->pool = 8000000;
}

static int parse_opts(int argc, char **argv, int start, Opts *o) {
  for (int i = start; i < argc; i++) {
    const char *a = argv[i];
    #define NEXT() (i + 1 < argc ? argv[++i] : "")
    if (!strcmp(a, "--fen"))          snprintf(o->fen, sizeof(o->fen), "%s", NEXT());
    else if (!strcmp(a, "--moves"))   snprintf(o->moves, sizeof(o->moves), "%s", NEXT());
    else if (!strcmp(a, "--time"))    o->secs = atof(NEXT());
    else if (!strcmp(a, "--nodes"))   o->nodes = atol(NEXT());
    else if (!strcmp(a, "--pool"))    o->pool = atol(NEXT());
    else if (!strcmp(a, "--seed"))    o->seed = (uint64_t)strtoull(NEXT(), NULL, 10);
    else if (!strcmp(a, "-v") || !strcmp(a, "--verbose")) o->verbose = 1;
    else if (!strcmp(a, "--persona")) {
      const char *n = NEXT();
      const Persona *pp = persona_find(n);
      if (!pp) { fprintf(stderr, "persona desconhecida: %s\n", n); persona_list(); return 0; }
      o->per = pp;
    } else { fprintf(stderr, "opcao desconhecida: %s\n", a); return 0; }
    #undef NEXT
  }
  return 1;
}

static int setup(Position *p, const Opts *o) {
  if (!strcmp(o->fen, "startpos")) pos_startpos(p);
  else if (!pos_from_fen(p, o->fen)) { fprintf(stderr, "FEN invalida\n"); return 0; }
  if (o->moves[0]) {
    char buf[4096]; snprintf(buf, sizeof(buf), "%s", o->moves);
    char *save = NULL, *tok;
    for (tok = strtok_r(buf, " ,", &save); tok; tok = strtok_r(NULL, " ,", &save)) {
      if (!*tok) continue;
      /* ignora numeros de lance tipo "1." */
      char *dot = strchr(tok, '.');
      if (dot) { tok = dot + 1; if (!*tok) continue; }
      Move m = parse_move(p, tok);
      if (m == MOVE_NONE) { fprintf(stderr, "lance ilegal/irreconhecivel: %s\n", tok); return 0; }
      do_move(p, m);
    }
  }
  return 1;
}

static const char *outcome(Position *p, char *buf) {
  MoveList l; gen_legal(p, &l);
  if (l.n == 0) {
    if (in_check(p, p->stm)) sprintf(buf, "Xeque-mate. %s vencem.",
                                     p->stm == WHITE ? "As pretas" : "As brancas");
    else sprintf(buf, "Rei afogado. Empate.");
    return buf;
  }
  if (p->halfmove >= 100) { sprintf(buf, "Empate pela regra dos 50 lances."); return buf; }
  if (is_draw_material(p)) { sprintf(buf, "Empate por material insuficiente."); return buf; }
  if (is_repetition(p))    { sprintf(buf, "Empate por repeticao."); return buf; }
  return NULL;
}

/* ------------------------------------------------------- decidir um lance  */
typedef struct { Move move; char san[12]; char reason[512]; int from_book; } Decision;

static void decide(Position *p, const Opts *o, Decision *d, int show)
{
  uint64_t rng = o->seed ^ (p->key * 0x2545F4914F6CDD1DULL);
  char bn[48];
  Move bm = book_pick(p, o->per->book_weight, &rng, bn);
  if (bm != MOVE_NONE) {
    d->move = bm; d->from_book = 1;
    move_to_san(p, bm, d->san);
    snprintf(d->reason, sizeof(d->reason), "%s -- teoria conhecida, %s.", d->san, bn);
    if (show) printf("  %s\n", d->reason);
    return;
  }
  SearchLimits lim = { o->secs * 1000.0, o->nodes, o->verbose,
                       o->per->strength, rng ? rng : 1 };
  /* orcamento de pensamento humanizado: posicoes afiadas merecem mais tempo */
  SearchResult res;
  think(p, &o->per->style, &lim, &res);
  if (res.nroots == 0) { d->move = MOVE_NONE; d->reason[0] = 0; return; }

  d->move = humanize_choice(&res, p, &o->per->style, o->per->strength,
                            &rng, d->reason, sizeof(d->reason));
  d->from_book = 0;
  move_to_san(p, d->move, d->san);

  if (show) {
    if (o->verbose) {
      printf("  candidatos (prob. de vitoria | incerteza | visitas | prior):\n");
      int k = res.nroots < 6 ? res.nroots : 6;
      for (int i = 0; i < k; i++) {
        RootMove *r = &res.roots[i];
        printf("    %-7s %5.1f%%  +-%4.1f  %8ld  %4.1f%%   %s%s\n",
               r->san, r->mu * 100.0, r->sigma * 100.0, r->visits,
               r->prior * 100.0, r->pv,
               r->proven == 1 ? "  [mate]" : (r->proven == -1 ? "  [perdido]" : ""));
      }
      printf("  arvore: %ld nos, prof. %d, %.0f ms, incerteza na raiz %.1f%%\n",
             res.nodes, res.depth_reached, res.elapsed_ms, res.root_sigma * 100.0);
    }
    printf("  %s\n", d->reason);
  }
}

/* ------------------------------------------------------------------ perft  */
static int cmd_perft(int argc, char **argv) {
  int depth = argc > 2 ? atoi(argv[2]) : 5;
  Opts o; defaults(&o);
  if (!parse_opts(argc, argv, 3, &o)) return 1;
  Position p; if (!setup(&p, &o)) return 1;
  for (int d = 1; d <= depth; d++) {
    double t = now_ms();
    U64 n = perft(&p, d);
    double dt = now_ms() - t;
    printf("perft(%d) = %-14llu  %7.0f ms  %6.2f Mnps\n", d,
           (unsigned long long)n, dt, dt > 0 ? n / dt / 1000.0 : 0.0);
  }
  return 0;
}

/* ---------------------------------------------------------------- analyze  */
static int cmd_analyze(int argc, char **argv) {
  Opts o; defaults(&o);
  if (!parse_opts(argc, argv, 2, &o)) return 1;
  Position p; if (!setup(&p, &o)) return 1;
  search_init(o.pool);
  pos_print(&p);
  SearchLimits lim = { o.secs * 1000.0, o.nodes, 1, o.per->strength, o.seed | 1 };
  SearchResult res;
  think(&p, &o.per->style, &lim, &res);
  printf("  persona: %s\n", o.per->name);
  printf("  %-7s %7s %7s %10s %7s  %s\n",
         "lance", "vitoria", "incert", "visitas", "prior", "variante principal");
  int k = res.nroots < 10 ? res.nroots : 10;
  for (int i = 0; i < k; i++) {
    RootMove *r = &res.roots[i];
    printf("  %-7s %6.1f%% %6.1f%% %10ld %6.1f%%  %s%s\n",
           r->san, r->mu * 100.0, r->sigma * 100.0, r->visits, r->prior * 100.0,
           r->pv, r->proven == 1 ? "  [MATE]" : (r->proven == -1 ? "  [perdido]" : ""));
  }
  printf("\n  arvore: %ld nos  prof.max %d  %.0f ms  incerteza raiz %.1f%%\n",
         res.nodes, res.depth_reached, res.elapsed_ms, res.root_sigma * 100.0);
  EvalTrace tr; evaluate_traced(&p, &o.per->style, &tr);
  printf("  avaliacao estatica: %+d cp (fase %d/256) | material %+d  pst %+d  "
         "mobil %+d  rei %+d  peoes %+d  ameacas %+d | volatilidade %.1f%%\n",
         tr.total_cp, tr.phase, tr.material, tr.pst, tr.mobility,
         tr.king_safety, tr.pawns, tr.threats, tr.sigma * 100.0);
  search_free();
  return 0;
}

/* ------------------------------------------------------------------ reply  */
static int cmd_reply(int argc, char **argv) {
  Opts o; defaults(&o);
  if (!parse_opts(argc, argv, 2, &o)) return 1;
  Position p; if (!setup(&p, &o)) return 1;
  search_init(o.pool);
  char buf[128];
  const char *end = outcome(&p, buf);
  if (end) { pos_print(&p); printf("%s\n", end); search_free(); return 0; }
  Decision d;
  printf("Pensando (%s, %.1fs)...\n", o.per->name, o.secs);
  decide(&p, &o, &d, 1);
  char uci[8]; move_to_uci(d.move, uci);
  do_move(&p, d.move);
  pos_print(&p);
  printf("LANCE: %s  (%s)\n", d.san, uci);
  end = outcome(&p, buf);
  if (end) printf("%s\n", end);
  search_free();
  return 0;
}

/* -------------------------------------------------------------- selfplay   */
static int cmd_match(int argc, char **argv) {
  Opts o; defaults(&o);
  const char *p2name = NULL;
  int games = 1;
  /* --vs <persona> e --games <n> sao especificos deste comando */
  static char filtered[64][256]; int nf = 0;
  char *fargv[64]; fargv[0] = argv[0]; fargv[1] = argv[1]; nf = 2;
  for (int i = 2; i < argc; i++) {
    if (!strcmp(argv[i], "--vs") && i + 1 < argc) { p2name = argv[++i]; continue; }
    if (!strcmp(argv[i], "--games") && i + 1 < argc) { games = atoi(argv[++i]); continue; }
    fargv[nf++] = argv[i];
  }
  (void)filtered;
  if (!parse_opts(nf, fargv, 2, &o)) return 1;
  const Persona *A = o.per;
  const Persona *B = p2name ? persona_find(p2name) : o.per;
  if (!B) { fprintf(stderr, "persona desconhecida: %s\n", p2name); return 1; }

  search_init(o.pool);
  int wa = 0, wb = 0, dr = 0;
  for (int g = 0; g < games; g++) {
    Position p; if (!setup(&p, &o)) { search_free(); return 1; }
    const Persona *white = (g % 2 == 0) ? A : B;
    const Persona *black = (g % 2 == 0) ? B : A;
    printf("\n=== Partida %d: brancas %s  x  pretas %s ===\n", g + 1,
           white->name, black->name);
    char buf[128]; const char *end = NULL;
    char pgn[8192]; pgn[0] = 0;
    for (int ply = 0; ply < 300; ply++) {
      end = outcome(&p, buf);
      if (end) break;
      Opts oo = o;
      oo.per = (p.stm == WHITE) ? white : black;
      oo.seed = o.seed + (uint64_t)g * 7919 + (uint64_t)ply * 104729;
      Decision d;
      decide(&p, &oo, &d, 0);
      if (d.move == MOVE_NONE) break;
      char tmp[32];
      if (p.stm == WHITE) snprintf(tmp, sizeof(tmp), "%d. %s ", p.fullmove, d.san);
      else                snprintf(tmp, sizeof(tmp), "%s ", d.san);
      strncat(pgn, tmp, sizeof(pgn) - strlen(pgn) - 1);
      do_move(&p, d.move);
    }
    if (!end) { end = "Limite de lances."; }
    printf("%s\n--> %s\n", pgn, end);
    int wwin = strstr(end, "As brancas vencem") != NULL;
    int bwin = strstr(end, "As pretas vencem") != NULL;
    if (wwin) { if (white == A) wa++; else wb++; }
    else if (bwin) { if (black == A) wa++; else wb++; }
    else dr++;
  }
  printf("\nPlacar: %s %d - %d %s  (%d empates)\n", A->name, wa, wb, B->name, dr);
  search_free();
  return 0;
}

/* ------------------------------------------------------------------ play   */
static int cmd_play(int argc, char **argv) {
  Opts o; defaults(&o);
  int human_white = 1;
  char *fargv[64]; int nf = 2; fargv[0] = argv[0]; fargv[1] = argv[1];
  for (int i = 2; i < argc; i++) {
    if (!strcmp(argv[i], "--color") && i + 1 < argc) {
      const char *c = argv[++i];
      human_white = (c[0] == 'w' || c[0] == 'b' ? (c[0] == 'w') : 1);
      continue;
    }
    fargv[nf++] = argv[i];
  }
  if (!parse_opts(nf, fargv, 2, &o)) return 1;
  Position p; if (!setup(&p, &o)) return 1;
  search_init(o.pool);
  printf("Belief -- engine probabilistica.  persona=%s  tempo=%.1fs\n",
         o.per->name, o.secs);
  printf("Digite lances em SAN (Nf3) ou coordenadas (g1f3). "
         "Comandos: undo, fen, eval, quit\n");
  char line[256]; char buf[128];
  while (1) {
    pos_print(&p);
    const char *end = outcome(&p, buf);
    if (end) { printf("%s\n", end); break; }
    int human_turn = (p.stm == WHITE) == human_white;
    if (human_turn) {
      printf("seu lance> "); fflush(stdout);
      if (!fgets(line, sizeof(line), stdin)) break;
      line[strcspn(line, "\r\n")] = 0;
      if (!*line) continue;
      if (!strcmp(line, "quit") || !strcmp(line, "sair")) break;
      if (!strcmp(line, "fen")) { char f[128]; pos_to_fen(&p, f); printf("%s\n", f); continue; }
      if (!strcmp(line, "undo")) { if (p.ply >= 2) { undo_move(&p); undo_move(&p); } continue; }
      if (!strcmp(line, "eval")) {
        EvalTrace tr; Belief b = evaluate_traced(&p, &o.per->style, &tr);
        printf("cp=%+d  P(brancas)=%.1f%%  volatilidade=%.1f%%\n",
               tr.total_cp, b.mu * 100.0, b.sigma * 100.0);
        continue;
      }
      Move m = parse_move(&p, line);
      if (m == MOVE_NONE) { printf("lance invalido: %s\n", line); continue; }
      do_move(&p, m);
    } else {
      Decision d;
      printf("pensando...\n");
      Opts oo = o; oo.seed = o.seed + (uint64_t)p.ply * 7919;
      decide(&p, &oo, &d, 1);
      if (d.move == MOVE_NONE) break;
      do_move(&p, d.move);
    }
  }
  search_free();
  return 0;
}

/* ------------------------------------------------------------------- uci   */
static int cmd_uci(void) {
  Opts o; defaults(&o);
  Position p; pos_startpos(&p);
  search_init(o.pool);
  char line[8192];
  setvbuf(stdout, NULL, _IOLBF, 0);
  while (fgets(line, sizeof(line), stdin)) {
    line[strcspn(line, "\r\n")] = 0;
    if (!strcmp(line, "uci")) {
      printf("id name Belief (probabilistic)\nid author projeto\n");
      printf("option name Persona type combo default mestre var mestre var tatico "
             "var posicional var romantico var solido var clube var amador var iniciante\n");
      printf("uciok\n");
    } else if (!strcmp(line, "isready")) printf("readyok\n");
    else if (!strncmp(line, "setoption", 9)) {
      char *v = strstr(line, "value ");
      if (v) { const Persona *pp = persona_find(v + 6); if (pp) o.per = pp; }
    }
    else if (!strcmp(line, "ucinewgame")) pos_startpos(&p);
    else if (!strncmp(line, "position", 8)) {
      const char *s = line + 8;
      while (*s == ' ') s++;
      if (!strncmp(s, "startpos", 8)) { pos_startpos(&p); s += 8; }
      else if (!strncmp(s, "fen", 3)) {
        s += 3; while (*s == ' ') s++;
        char f[128];
        const char *m = strstr(s, " moves");
        int len = m ? (int)(m - s) : (int)strlen(s);
        if (len > 127) len = 127;
        memcpy(f, s, (size_t)len); f[len] = 0;
        pos_from_fen(&p, f);
        s += len;
      }
      const char *mv = strstr(s, "moves");
      if (mv) {
        char b[8192]; snprintf(b, sizeof(b), "%s", mv + 5);
        char *save = NULL, *tok;
        for (tok = strtok_r(b, " ", &save); tok; tok = strtok_r(NULL, " ", &save)) {
          Move m = parse_move(&p, tok);
          if (m != MOVE_NONE) do_move(&p, m);
        }
      }
    } else if (!strncmp(line, "go", 2)) {
      double mt = o.secs * 1000.0;
      char *q;
      if ((q = strstr(line, "movetime"))) mt = atof(q + 8);
      else {
        double wt = 0, bt = 0, winc = 0, binc = 0;
        if ((q = strstr(line, "wtime"))) wt = atof(q + 5);
        if ((q = strstr(line, "btime"))) bt = atof(q + 5);
        if ((q = strstr(line, "winc")))  winc = atof(q + 4);
        if ((q = strstr(line, "binc")))  binc = atof(q + 4);
        double t = p.stm == WHITE ? wt : bt, inc = p.stm == WHITE ? winc : binc;
        if (t > 0) mt = t / 28.0 + inc * 0.75;
      }
      if (mt < 30) mt = 30;
      uint64_t rng = (uint64_t)now_ms() ^ p.key;
      char bn[48];
      Move bm = book_pick(&p, o.per->book_weight, &rng, bn);
      if (bm == MOVE_NONE) {
        SearchLimits lim = { mt, 0, 0, o.per->strength, rng | 1 };
        SearchResult res;
        think(&p, &o.per->style, &lim, &res);
        char reason[512];
        bm = humanize_choice(&res, &p, &o.per->style, o.per->strength, &rng,
                             reason, sizeof(reason));
        if (res.nroots) {
          int cp = (int)(-logf(1.0f / (res.roots[0].mu + 1e-6f) - 1.0f) * 290.0f);
          printf("info depth %d nodes %ld time %d score cp %d pv %s\n",
                 res.depth_reached, res.nodes, (int)res.elapsed_ms, cp,
                 res.roots[0].pv);
        }
      }
      char u[8]; move_to_uci(bm, u);
      printf("bestmove %s\n", u);
    } else if (!strcmp(line, "quit")) break;
  }
  search_free();
  return 0;
}

/* ------------------------------------------------------------------ bench  */
static int cmd_bench(int argc, char **argv) {
  static const char *POS[] = {
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
    "2rq1rk1/pp1bppbp/3p1np1/8/2BNP3/2N1BP2/PPPQ2PP/2KR3R w - - 0 1",
    "8/8/8/4k3/8/3K4/4P3/8 w - - 0 1",
  };
  Opts o; defaults(&o);
  if (!parse_opts(argc, argv, 2, &o)) return 1;
  search_init(o.pool);
  long tot = 0; double tt = 0;
  for (int i = 0; i < 6; i++) {
    Position p; pos_from_fen(&p, POS[i]);
    SearchLimits lim = { o.secs * 1000.0, o.nodes, 0, 100, 12345 + i };
    SearchResult res;
    think(&p, &o.per->style, &lim, &res);
    tot += res.nodes; tt += res.elapsed_ms;
    printf("  %-8s %5.1f%%  prof %2d  %8ld nos  %s\n",
           res.nroots ? res.roots[0].san : "-",
           res.nroots ? res.roots[0].mu * 100.0 : 50.0,
           res.depth_reached, res.nodes, res.nroots ? res.roots[0].pv : "");
  }
  printf("\ntotal %ld nos em %.0f ms = %.0f nos/s\n", tot, tt, tot / (tt / 1000.0));
  search_free();
  return 0;
}

static void usage(void) {
  printf(
  "Belief -- engine de xadrez probabilistica (sem alfa-beta, sem Stockfish)\n\n"
  "uso: belief <comando> [opcoes]\n\n"
  "comandos:\n"
  "  play      [--color w|b]        jogar contra a engine no terminal\n"
  "  reply     --moves \"...\"        devolve o proximo lance da engine\n"
  "  analyze   [--fen ...]          lista candidatos com probabilidades\n"
  "  match     [--vs P] [--games N] engine contra engine\n"
  "  perft     <prof> [--fen ...]   validacao do gerador de lances\n"
  "  bench                          desempenho da busca\n"
  "  personas                       lista os estilos disponiveis\n"
  "  uci                            protocolo UCI (Arena, CuteChess, ...)\n\n"
  "opcoes:\n"
  "  --fen <FEN> | startpos      --moves \"e2e4 e7e5\" | \"e4 e5\"\n"
  "  --time <seg>                --nodes <n>        --pool <nos>\n"
  "  --persona <nome>            --seed <n>         -v\n");
}

int main(int argc, char **argv) {
  belief_init();
  if (argc < 2) { usage(); return 0; }
  const char *c = argv[1];
  if (!strcmp(c, "perft"))    return cmd_perft(argc, argv);
  if (!strcmp(c, "analyze"))  return cmd_analyze(argc, argv);
  if (!strcmp(c, "reply"))    return cmd_reply(argc, argv);
  if (!strcmp(c, "match"))    return cmd_match(argc, argv);
  if (!strcmp(c, "play"))     return cmd_play(argc, argv);
  if (!strcmp(c, "bench"))    return cmd_bench(argc, argv);
  if (!strcmp(c, "uci"))      return cmd_uci();
  if (!strcmp(c, "personas")) { persona_list();
    printf("\nlivro: %d posicoes, %d linhas com problema\n",
           book_size(), book_problems()); return 0; }
  usage();
  return 0;
}
