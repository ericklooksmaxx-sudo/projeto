# Xadrez neural: Alfa x Beta

Duas redes neurais que **começam sem saber nada de xadrez** e aprendem jogando
uma contra a outra, por tentativa e erro (aprendizado por reforço).

## Como funciona

- **O que a rede vê:** onde está cada peça (12 "planos" 8×8, sempre do ponto de vista
  de quem tem a vez) e os direitos de roque. Ninguém diz a ela quanto vale uma dama,
  que o centro importa ou o que é um garfo.
- **O que a rede faz:** dá uma nota de -1 (vou perder) a +1 (vou ganhar) para uma posição.
  Para jogar, ela olha todas as posições que surgem depois de cada lance legal e escolhe
  a que acha melhor. Às vezes ela joga um lance aleatório de propósito, para explorar.
- **Como aprende (TD(λ), o mesmo princípio do TD-Gammon):** no fim de cada partida, o
  resultado (vitória/empate/derrota) é propagado para trás. Cada posição aprende a
  prever a próxima avaliação, e a última posição aprende com o resultado real.
  Depois de dezenas de milhares de partidas, as notas passam a refletir o que de fato
  leva à vitória.
- **As únicas regras dadas:** os lances legais, e que um xeque-mate encerra o jogo
  (python-chess). Material, posição e tática a rede descobre sozinha.
- **Alfa e Beta:** mesma arquitetura (MLP 772 → 512 → 128 → 1), sementes diferentes e
  um "temperamento" diferente: Alfa usa λ=0,7 (confia mais na própria avaliação do próximo
  lance) e Beta usa λ=0,9 (confia mais no resultado final da partida).

Para medir o progresso, a cada 10 rodadas as redes jogam contra:
- **Aleatório**: escolhe lances ao acaso;
- **Materialista**: referência fixa escrita à mão que olha 1 lance à frente e só conta
  material (P=1, C=B=3, T=5, D=9). A rede nunca recebe essa informação; ela precisa
  descobrir sozinha.

A "sonda" no log mostra quanto a rede acha que vale começar a partida com uma peça
a mais (a posição inicial sem uma peça do adversário). Esses números crescem conforme
ela aprende a ordem de valor das peças.

## Uso

```bash
pip install torch chess numpy
python train.py --hours 3          # treina (retoma do último checkpoint)
python play.py --rede alfa         # jogar contra a rede no terminal (você de brancas)
python play.py --rede beta --cor pretas --profundidade 2
```

`--profundidade 1` é a rede pura, do jeito que ela jogou durante o treino.
`--profundidade 2/3` faz uma busca minimax curta e usa a rede para avaliar as posições
no fim da busca.

Arquivos:
- `core.py`: codificação do tabuleiro, rede e geração de lances
- `train.py`: autojogo, aprendizado e avaliações
- `play.py`: jogar contra a rede
- `log.jsonl`: histórico completo do treino
- `checkpoints/`: pesos treinados de Alfa e Beta e uma partida Alfa x Beta em PGN
