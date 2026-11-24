/* ============================================================================
 *  core.h  --  Tipos, tabuleiro, geracao de lances e interfaces publicas.
 *
 *  Projeto: "Belief" -- uma engine de xadrez probabilistica.
 *
 *  Esta engine NAO usa alfa-beta, NAO usa quiescence search, NAO usa NNUE,
 *  NAO contem nem deriva de codigo do Stockfish. A arquitetura e outra:
 *
 *    avaliacao  -> uma CRENCA (mu, sigma) sobre o resultado da partida
 *    busca      -> Thompson Sampling em arvore + minimax probabilistico
 *    prior      -> modelo de atencao humana (quais lances um humano olha)
 *    decisao    -> camada de personalidade, risco e livro de aberturas
 * ==========================================================================*/
#ifndef BELIEF_CORE_H
#define BELIEF_CORE_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

/* ------------------------------------------------------------------ basicos */
typedef uint64_t U64;

enum { WHITE = 0, BLACK = 1, BOTH = 2 };
enum { PAWN = 0, KNIGHT, BISHOP, ROOK, QUEEN, KING, NO_PTYPE = 6 };
enum { NO_PIECE = 12 };
#define PIECE(c, t)   ((c) * 6 + (t))
#define PC_COLOR(p)   ((p) / 6)
#define PC_TYPE(p)    ((p) % 6)

enum {
  A1,B1,C1,D1,E1,F1,G1,H1, A2,B2,C2,D2,E2,F2,G2,H2,
  A3,B3,C3,D3,E3,F3,G3,H3, A4,B4,C4,D4,E4,F4,G4,H4,
  A5,B5,C5,D5,E5,F5,G5,H5, A6,B6,C6,D6,E6,F6,G6,H6,
  A7,B7,C7,D7,E7,F7,G7,H7, A8,B8,C8,D8,E8,F8,G8,H8, NO_SQ = 64
};
#define RANK_OF(s) ((s) >> 3)
#define FILE_OF(s) ((s) & 7)

/* direitos de roque (bitmask) */
enum { CR_WK = 1, CR_WQ = 2, CR_BK = 4, CR_BQ = 8 };

/* ------------------------------------------------------------------- lances */
/* 16 bits:  from(6) | to(6) | flag(4)                                       */
typedef uint16_t Move;
enum {
  MF_QUIET = 0, MF_DPUSH = 1, MF_KCASTLE = 2, MF_QCASTLE = 3,
  MF_CAP   = 4, MF_EP    = 5,
  MF_PN    = 8, MF_PB = 9,  MF_PR = 10, MF_PQ = 11,
  MF_PNC   = 12, MF_PBC = 13, MF_PRC = 14, MF_PQC = 15
};
#define MK_MOVE(f, t, fl) ((Move)((f) | ((t) << 6) | ((fl) << 12)))
#define M_FROM(m)  ((int)((m) & 63))
#define M_TO(m)    ((int)(((m) >> 6) & 63))
#define M_FLAG(m)  ((int)((m) >> 12))
#define M_IS_CAP(m)   ((M_FLAG(m) & 4) != 0)
#define M_IS_PROMO(m) ((M_FLAG(m) & 8) != 0)
#define M_PROMO_PT(m) (KNIGHT + (M_FLAG(m) & 3))
#define MOVE_NONE ((Move)0)

#define MAX_MOVES 256
typedef struct { Move m[MAX_MOVES]; int n; } MoveList;

/* ----------------------------------------------------------------- posicao  */
#define MAX_PLY 512

typedef struct {
  Move     move;
  uint8_t  captured;     /* NO_PIECE se nenhuma */
  uint8_t  castle;
  uint8_t  ep;
  uint16_t halfmove;
  U64      key;
} Undo;

typedef struct {
  U64      bb[12];       /* bitboard por peca                               */
  U64      occ[3];       /* ocupacao por cor + total                        */
  uint8_t  board[64];    /* peca em cada casa, NO_PIECE se vazia            */
  uint8_t  stm;          /* lado a jogar                                    */
  uint8_t  castle;       /* direitos de roque                               */
  uint8_t  ep;           /* casa de en passant ou NO_SQ                     */
  uint16_t halfmove;     /* regra dos 50 lances                             */
  uint16_t fullmove;
  U64      key;          /* hash zobrist                                    */
  int      ply;          /* profundidade na pilha de undo                   */
  Undo     stack[MAX_PLY];
  U64      hist[MAX_PLY + 1024];  /* historico de chaves p/ repeticao       */
  int      histN;
} Position;

/* ------------------------------------------------------------ bit twiddling */
static inline int  popcount(U64 b) { return __builtin_popcountll(b); }
static inline int  lsb(U64 b)      { return __builtin_ctzll(b); }
static inline int  pop_lsb(U64 *b) { int s = lsb(*b); *b &= *b - 1; return s; }
#define BIT(s) (1ULL << (s))

extern const U64 FILE_BB[8];
extern const U64 RANK_BB[8];

/* --------------------------------------------------------------- board.c    */
void  belief_init(void);                     /* tabelas + zobrist            */
void  pos_startpos(Position *p);
int   pos_from_fen(Position *p, const char *fen);
void  pos_to_fen(const Position *p, char *out);
void  pos_print(const Position *p);

U64   attacks_pawn(int color, int sq);
U64   attacks_knight(int sq);
U64   attacks_king(int sq);
U64   attacks_bishop(int sq, U64 occ);
U64   attacks_rook(int sq, U64 occ);
U64   attacks_queen(int sq, U64 occ);
U64   attacks_of(const Position *p, int piece, int sq);

int   sq_attacked(const Position *p, int sq, int by_color);
U64   attackers_to(const Position *p, int sq, int by_color, U64 occ);
int   in_check(const Position *p, int color);
int   king_sq(const Position *p, int color);

void  gen_pseudo(const Position *p, MoveList *l);      /* todos              */
void  gen_pseudo_captures(const Position *p, MoveList *l);
void  gen_legal(const Position *p, MoveList *l);

int   do_move(Position *p, Move m);     /* 1 se legal (desfaz se ilegal)     */
void  undo_move(Position *p);
void  do_null(Position *p);
void  undo_null(Position *p);

int   is_repetition(const Position *p);
int   is_draw_material(const Position *p);
int   move_is_legal(const Position *p, Move m);

int   see(const Position *p, Move m);   /* static exchange evaluation (cp)   */
int   see_sq(const Position *p, int sq, int side); /* troca na casa          */

/* notacao */
void  move_to_uci(Move m, char *out);
Move  move_from_uci(const Position *p, const char *s);
void  move_to_san(const Position *p, Move m, char *out);
Move  move_from_san(const Position *p, const char *s);
Move  parse_move(const Position *p, const char *s);  /* UCI ou SAN          */

U64   perft(Position *p, int depth);

/* --------------------------------------------------------------- eval.c     */
/*  A avaliacao devolve uma CRENCA, nao um numero:
 *    mu    = pontuacao esperada para as BRANCAS em [0,1]
 *    sigma = incerteza (volatilidade tatica) dessa crenca
 */
typedef struct { float mu, sigma; } Belief;

typedef struct {               /* pesos de estilo (persona)                  */
  float aggression;            /* peso do ataque ao rei                      */
  float materialism;           /* peso do material puro                      */
  float activity;              /* peso de mobilidade/espaco                  */
  float structure;             /* peso da estrutura de peoes                 */
  float risk;                  /* apetite por variancia                      */
  float creativity;            /* temperatura na escolha final               */
  float patience;              /* tolerancia a posicoes fechadas             */
} Style;

typedef struct {               /* diagnostico legivel da avaliacao           */
  int material, pst, mobility, king_safety, pawns, threats, space, total_cp;
  int phase;                   /* 0 = final puro .. 256 = abertura           */
  float sigma;
  int   hanging_us, hanging_them, checks_avail;
} EvalTrace;

void   eval_init(void);
Belief evaluate(const Position *p, const Style *st);
Belief evaluate_traced(const Position *p, const Style *st, EvalTrace *tr);
int    eval_cp(const Position *p, const Style *st);    /* centipeoes, brancas */
float  cp_to_score(int cp, int phase);
int    game_phase(const Position *p);

/* --------------------------------------------------------------- search.c   */
typedef struct {
  double  time_ms;         /* orcamento de tempo                            */
  long    max_nodes;       /* orcamento de nos da arvore                    */
  int     verbose;         /* imprime progresso                             */
  int     strength;        /* 0..100 (100 = forca maxima)                    */
  uint64_t seed;
} SearchLimits;

typedef struct {
  Move   move;
  float  mu;               /* pontuacao esperada p/ o lado que joga          */
  float  sigma;
  float  prior;
  long   visits;
  int    proven;           /* -1 perde forcado, 0 nada, +1 ganha forcado     */
  int    mate_in;          /* lances ate o mate (0 = desconhecido)           */
  char   san[12];
  char   pv[192];
} RootMove;

typedef struct {
  RootMove roots[MAX_MOVES];
  int      nroots;
  Move     best;
  float    best_mu;
  float    root_sigma;
  long     nodes;
  int      depth_reached;
  double   elapsed_ms;
  int      book;            /* 1 se o lance veio do livro                   */
  char     reason[512];     /* justificativa em linguagem natural           */
} SearchResult;

void search_init(long node_capacity);
void search_free(void);
void think(Position *p, const Style *st, const SearchLimits *lim,
           SearchResult *res);

/* --------------------------------------------------------------- persona.c  */
typedef struct {
  const char *name;
  const char *desc;
  Style       style;
  int         strength;
  float       book_weight;   /* 0 = ignora livro, 1 = segue sempre          */
} Persona;

const Persona *persona_find(const char *name);
void           persona_list(void);
const Persona *persona_default(void);

void  book_init(void);
Move  book_pick(const Position *p, float weight, uint64_t *rng, char *out_name);

/* escolha final humanizada entre os candidatos da raiz */
Move  humanize_choice(const SearchResult *res, const Position *p,
                      const Style *st, int strength, uint64_t *rng,
                      char *reason_out, int reason_cap);

/* ------------------------------------------------------------------- utils  */
double now_ms(void);
static inline uint64_t rng_next(uint64_t *s) {   /* splitmix64               */
  uint64_t z = (*s += 0x9E3779B97F4A7C15ULL);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  return z ^ (z >> 31);
}
static inline double rng_unit(uint64_t *s) {
  return (double)(rng_next(s) >> 11) * (1.0 / 9007199254740992.0);
}
double rng_normal(uint64_t *s);

#endif /* BELIEF_CORE_H */
