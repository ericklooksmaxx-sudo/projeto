# Belief — uma engine de xadrez probabilística

Engine de xadrez escrita do zero em C11. **Nenhuma linha vem do Stockfish**, e
mais do que isso: a arquitetura é deliberadamente outra. Não há busca
alfa-beta, não há janelas de aspiração, não há poda de movimento nulo, não há
quiescence search, não há NNUE nem rede neural nenhuma.

O princípio é único e atravessa o programa inteiro:

> A engine nunca sabe quanto vale uma posição. Ela tem uma **crença** sobre
> quanto vale, e sabe o tamanho da própria ignorância. Toda decisão —
> onde pensar, o que acreditar, o que jogar — sai dessa incerteza.

---

## Como funciona

### 1. Avaliar é acreditar, não medir

`evaluate()` não devolve centipeões. Devolve uma distribuição:

```c
typedef struct { float mu, sigma; } Belief;
```

* `mu` — pontuação esperada das brancas, em `[0,1]` (1 = ganha, 0.5 = empata)
* `sigma` — **volatilidade**: o quanto a própria engine desconfia desse número

`sigma` cresce com peças penduradas, damas no tabuleiro, reis expostos e
xeques disponíveis; encolhe em finais técnicos. Valores medidos:

| posição | sigma |
|---|---|
| final de peões travados | 4,1% |
| final de torres | 5,6% |
| posição inicial | 6,6% |
| meio-jogo com combinação latente (WAC.001) | 16,2% |
| Kiwipete (peças penduradas dos dois lados) | 28,2% |

Essa é a peça central. Em uma engine convencional, "+0,30" e "+0,30" são a
mesma coisa. Aqui, `0,53 ± 0,02` e `0,53 ± 0,22` são posições completamente
diferentes, e a engine age de forma diferente em cada uma.

### 2. Buscar é amostrar (Thompson Sampling em árvore)

Em cada nó, para cada lance candidato, sorteia-se um valor da posterior dele:

```
v_i ~ N(mu_i, res_i²)       e desce-se pelo maior sorteio
```

Isso é **Thompson Sampling**: um lance recebe esforço de busca exatamente na
proporção da probabilidade de ele ser realmente o melhor. Não há "profundidade
N" — a árvore cresce funda onde a dúvida é grande e para onde já não há dúvida.

### 3. O valor do pai não é o máximo dos filhos

O backup usa a **aproximação de Clark** para `E[max_i X_i]` com
`X_i ~ N(mu_i, res_i)`, dobrando os filhos dois a dois:

```
θ = √(v + r_i²)      d = (m − z_i)/θ
E[max]  = m·Φ(d) + z_i·(1−Φ(d)) + θ·φ(d)
E[max²] = (m²+v)·Φ(d) + (z_i²+r_i²)·(1−Φ(d)) + (m+z_i)·θ·φ(d)
```

`E[max]` é estritamente maior que `max(mu_i)`, e a diferença é literalmente
"a chance de haver aqui algo melhor do que eu já entendi". Quando as
incertezas vão a zero, isso converge **exatamente** para o minimax. É minimax
probabilístico de verdade, não uma média ponderada disfarçada.

A incerteza também encolhe 10% por nível (`GAMMA`). É por isso que procurar
mais fundo deixa a engine mais *confiante*, não só mais lenta.

### 4. Prior = modelo de atenção humana

Antes de buscar, cada lance recebe uma probabilidade a priori de **um jogador
forte sequer cogitar aquele lance**: SEE da captura, xeque, promoção, roque,
peça ameaçada que foge, casa batida por peão inimigo, desenvolvimento na
abertura, aproximação do rei adversário, ganho estático de crença. Softmax
sobre isso dá o prior, que entra na busca como otimismo inicial.

Na posição depois de `1.e4 Cf6 2.e5 Cd5 3.d4 d6 4.c4 dxe5 5.cxd5 exd4 6.Dxd4 c6
7.Cc3 cxd5 8.Dxd5`, o prior para `8...Dxd5` é **75,6%** — a engine, como um
humano, olha primeiro para a recaptura óbvia.

### 5. Onde a avaliação estática mente

Um xeque ou um sacrifício são exatamente as posições em que o valor estático é
menos confiável. A engine não mente sobre o *valor* desses lances — ela
aumenta a *incerteza* deles (`×2,7` para xeque, `×2,3` para sacrifício). O
Thompson Sampling então vai investigar, porque é lá que há informação a ganhar.

É assim, sem nenhuma regra de "estenda xeques", que a engine encontra
`1...Dd1+!! Rxd1 Bg4+ Rc1 Td1#` — com o mate **provado**, não estimado.

### 6. Solver exato acoplado

Mates e empates forçados sobem pela árvore de forma exata, não probabilística.
A engine não "quase vê" um mate: ela o prova, e então para de pensar. Quando
está perdida à força, ela diz isso.

### 7. A camada humana

* **Personas** com pesos de estilo (agressão, materialismo, atividade,
  estrutura, risco, criatividade, paciência) e força de 0 a 100.
* **Apetite por risco dependente do placar**: `λ = (risco−1)·0,55 + (0,5−μ)·0,75`.
  Quem está pior procura variância; quem está melhor simplifica. Como gente.
* **Escolha final estocástica**: entre lances objetivamente equivalentes (dentro
  de uma janela estreita de probabilidade de vitória) a escolha é sorteada por
  temperamento. Quando um lance é claramente melhor, ela joga esse lance.
* **Livro de aberturas probabilístico** com 51 linhas principais e 645 posições,
  amostrado por peso — ela não repete a mesma partida.
* **Justificativa em português** gerada do traço da avaliação, não de templates
  fixos: *"Dxh7+ — força o mate e dá xeque e não deixa respirar. Minhas
  chances: 100%."*

---

## Uso

```bash
make

./belief play --color w --time 5         # jogar contra ela
./belief play --persona romantico        # ... contra outro temperamento
./belief analyze --fen "<FEN>" --time 10 # candidatos com probabilidades
./belief reply  --moves "e4 e5 Nf3"      # só o próximo lance
./belief match  --vs tatico --games 4    # persona contra persona
./belief perft 6                         # validação do gerador de lances
./belief bench                           # desempenho da busca
./belief personas                        # estilos disponíveis
./belief uci                             # Arena, CuteChess, qualquer GUI
```

Opções: `--fen` `--moves` `--time` `--nodes` `--pool` `--persona` `--seed` `-v`.

Com `-v` ela mostra o raciocínio:

```
candidatos (prob. de vitoria | incerteza | visitas | prior):
  Qxh7+   100.0%  +- 0.0      4218   4.0%   Kxh7 hxg6#  [MATE]
  Qd2      52.4%  +- 5.5      5531   5.5%   Bh6 Qxh6 Qd5 hxg6
```

### Personas

| nome | força | caráter |
|---|---|---|
| `mestre` | 100 | equilibrada, o padrão |
| `tatico` | 100 | procura complicações e iniciativa |
| `posicional` | 100 | pequenas vantagens, odeia risco inútil |
| `romantico` | 100 | ataque e sacrifício, século XIX |
| `solido` | 100 | profilaxia primeiro |
| `clube` | 72 | forte de clube, erra de vez em quando |
| `amador` | 45 | boas ideias, falha nas táticas |
| `iniciante` | 18 | uma jogada à frente, às vezes |

Força reduzida não é só menos tempo: é ruído calibrado na avaliação mais uma
janela de escolha mais larga — o jogador fraco *não vê* a tática, em vez de
vê-la e jogar outra coisa.

---

## Validação

Nada aqui foi aceito por parecer certo.

**Gerador de lances.** `perft` em 6 posições (5 padrão + 1 conferida aqui),
profundidades 4 a 6, incluindo 119 060 324 e 193 690 690 nós, além de
`perft divide` comparado nó a nó contra `tests/ref.py` — um gerador *mailbox* ingênuo escrito de forma
independente, sem bitboards, só para servir de testemunha.

```bash
./belief perft 6
python3 tests/ref.py "<FEN>" 4          # referência independente
```

**Mates.** `tests/mate.py` é um verificador exaustivo de mate forçado, sem
heurística e sem poda. Foi ele, e não a engine, que confirmou que
`WAC.004 = Qxh7+ Kxh7 hxg6#` e que `32.Tf1!` na partida abaixo é mate em 3.

**Táticas.** `tests/run_tactics.sh` — 14 posições, 13 acertos a 3 s.

**Partidas completas.** `tests/match.py` arbitra dois motores UCI usando o
gerador independente como juiz: lance ilegal = derrota imediata. Quatro
partidas completas sem uma única irregularidade.

---

## A partida de teste

Belief (pretas, persona `mestre`, 5 s/lance) contra o autor deste README
(brancas). A engine escolheu a Defesa Alekhine, desviou da teoria no 4º lance
preferindo o peão (`4...dxe5?!`), e foi punida.

```
1. e4 Nf6 2. e5 Nd5 3. d4 d6 4. c4 dxe5 5. cxd5 exd4 6. Qxd4 c6 7. Nc3 cxd5
8. Qxd5 Qxd5 9. Nxd5 e5 10. Nc7+ Kd8 11. Nxa8 Bb4+ 12. Bd2 Bxd2+ 13. Kxd2 Ke7
14. Nc7 Rd8+ 15. Ke2 Bg4+ 16. f3 Na6 17. fxg4 Nxc7 18. Rd1 Nb5 19. Rxd8 Kxd8
20. Nf3 e4 21. Nd4 Nxd4+ 22. Ke3 Nc6 23. Kxe4 Nb4 24. Bc4 f5+ 25. gxf5 b5
26. Bxb5 g6 27. fxg6 Ke7 28. gxh7 Nc2 29. h8=Q Ne3 30. Kxe3 Kd6 31. Qd8+ Ke6
32. Rf1 a6 33. Rf6+ Ke5 34. Qd4# 1-0
```

O que a partida mostrou:

* **Autoavaliação honesta.** Ela acompanhou a própria queda sem se enganar:
  49% → 39% → 34% → 28% → 21% → 8% → 0%.
* **Senso prático.** No 18º lance, estando material abaixo, recusou a troca de
  torres (`18...Cb5`) — evitar simplificações quando se está pior é instinto de
  jogador, e aqui sai do termo de risco, não de uma regra.
* **Escolha humanizada.** No 23º lance jogou `Nc6` (11%) tendo `Ne6` (12%)
  disponível: dentro da janela de equivalência, o temperamento decide.
* **Honestidade sobre o fim.** No 31º lance parou de buscar após 94 mil nós e
  anunciou *"estou perdido à força"* — e o verificador exaustivo confirmou que
  ela tinha razão.

E o que ela errou: `4...dxe5?!` é um viés materialista do prior — ela
prefere o peão concreto à linha principal `4...Cb6`. É o ponto mais fraco da
avaliação hoje.

---

## Estrutura

```
src/core.h      tipos, tabuleiro, interfaces
src/board.c     bitboards, Hyperbola Quintessence, SEE, SAN, perft
src/eval.c      avaliação como crença (mu, sigma)
src/search.c    Thompson Sampling + backup de Clark + solver
src/persona.c   personas, livro, escolha humanizada, justificativa
src/main.c      CLI e UCI
tests/ref.py    gerador de lances independente (testemunha)
tests/mate.py   verificador exaustivo de mate forçado
tests/match.py  árbitro de partidas UCI
```

Cerca de 500 mil posições avaliadas por segundo em um núcleo.

## Limitações conhecidas

* Um único núcleo; a árvore não é paralelizada.
* Táticas quietas e profundas (ganhos posicionais em 6+ lances sem xeques nem
  capturas) continuam sendo a fraqueza da abordagem — é o preço de não ter
  alfa-beta.
* Sem tabelas de finais; finais técnicos saem da avaliação e do solver.
* O viés materialista do prior na abertura, visível na partida acima.
