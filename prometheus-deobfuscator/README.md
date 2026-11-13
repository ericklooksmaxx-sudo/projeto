# prometheus-deobf

Desofuscador **estático** para scripts Lua protegidos com o
[Prometheus](https://github.com/prometheus-lua/Prometheus) (versão atual, com
`Cff` e a VM de registradores `Vmify`) **e com o fork antigo usado pelo
[WeAreDevs](https://wearedevs.net/obfuscator)** (`wearedevs.net/api/obfuscate`).
O formato é detectado automaticamente.

Ele desfaz todas as camadas dos presets `Minify`, `Weak`, `Cff`, `Vmify`,
`Medium` e `Strong` e devolve código Lua estruturado e legível
(`if`/`while`/`repeat`/`for`, `local function`, `obj:metodo()`...).

```
$ python3 -m prometheus_deobf ofuscado.lua -o limpo.lua -v
  - removed function wrapper (WrapInFunction)
  - decoded constants (string pool / ConstantArray / EncryptStrings)
  - unflattened 1 Cff dispatcher(s)
  - removed AntiTamper
  - devirtualized 1 VM program(s)
```

Exemplo (preset `Strong`, ~150 KB de saída ofuscada) → resultado:

```lua
local function func1(arg1)
    if arg1 < 2 then
        return arg1
    end
    return func1(arg1 - 1) + func1(arg1 - 2)
end
local var1 = {}
for i1 = 1, 10 do
    var1[#var1 + 1] = func1(i1)
end
print("fib:", table.concat(var1, ", "))
print(("Hello, World"):upper(), 12, 7)
```

Nomes de variáveis locais não existem mais no arquivo ofuscado, então são
regenerados (`var1`, `arg1`, `func1`, `i1`...). Globais (`print`, `table`...)
voltam com o nome original.

## Uso

Requer apenas Python 3.8+ (sem dependências).

```bash
python3 -m prometheus_deobf entrada.lua                # imprime no stdout
python3 -m prometheus_deobf entrada.lua -o saida.lua   # grava em arquivo
python3 -m prometheus_deobf - < entrada.lua            # lê do stdin
python3 -m prometheus_deobf entrada.lua -v             # mostra as camadas removidas
```

Como biblioteca:

```python
from prometheus_deobf import deobfuscate
codigo, relatorio = deobfuscate(open("x.lua", encoding="latin-1").read())
```

## WeAreDevs

O ofuscador do WeAreDevs é um Prometheus antigo (achatamento de fluxo + `ConstantArray` +
`EncryptStrings` + `AntiTamper` + `NumbersToExpressions`). Diferenças tratadas em `cff.py`:

* contêiner com 4 parâmetros `(pos, args, upvals, proxy)` e sem parâmetro de ambiente
  (o ambiente é um dos argumentos do envelope);
* sem `pack`/`unpack` próprios: listas de valores são tabelas simples `{f()}` e
  `unpack(t)` (sem campo `n`);
* a variável de posição `pos` e o registrador de retorno também servem de registradores
  temporários — só a última atribuição a `pos` no bloco é o salto;
* `nil` escrito como leitura de um global aleatório e inexistente (`ENV.GCTp3DUdOQMn`);
  no emulador, globais não-padrão e nunca atribuídos no programa valem `nil`;
* o salto de saída de função pode ser `cond and A or nil` (bloco de retorno sintético).

Como o ofuscador do WeAreDevs **não preserva a semântica** em alguns casos (perde `nil`
finais em listas de retorno e ignora `(f())` para truncar valores), o resultado pode
coincidir com o programa *original* numa linha e com o programa *ofuscado* em outra.
`tests/wad_roundtrip.py` aceita qualquer um dos dois como referência.

Para gerar amostras pela API pública (só o texto do script é enviado):

```bash
python3 tests/wad_samples.py amostras/ a.lua b.lua
python3 tests/wad_roundtrip.py amostras/ --orig diretorio_dos_originais
```

## "Estático"

O programa ofuscado **nunca é executado**. O código é analisado como AST. Os
únicos trechos avaliados são os *decodificadores* que o próprio Prometheus
injeta (tabela de strings, decodificador base64/base85 do `ConstantArray`,
função de decriptação do `EncryptStrings`, `rebuild` dos dados da VM). Eles
rodam num interpretador Lua próprio, escrito em Python (`emulator.py`), que:

* não tem I/O, `os`, `debug`, `load*`, `getfenv`... (só funções puras de
  `string`/`math`/`table`);
* tem limite de passos;
* só substitui uma chamada pelo seu resultado se ela não ler nem escrever
  estado que o resto do programa possa observar.

## Camadas tratadas

| Step do Prometheus      | Como é desfeito |
|-------------------------|-----------------|
| `NumbersToExpressions`  | constant folding com a semântica numérica do Lua 5.1 (`fold.py`) |
| `WrapInFunction`        | remove `return (function(...) ... end)(...)` (`unwrap.py`) |
| string pool do `Cff`    | emulação do prólogo + substituição de `pool[i]` (`emufold.py`) |
| `ConstantArray`         | idem: rotação + decodificação base64/base85/mixed emuladas, `wrapper(n)` vira a constante |
| `EncryptStrings`        | idem: `STR[DECRYPT(s, seed)]` vira a string em claro |
| `AntiTamper`            | reconhecido pela string `"Tamper Detected!"` + `local valid` / `if valid then` e removido |
| `Cff` (também WeAreDevs)| ver abaixo (`cff.py` + `ir.py`) |
| `Vmify`                 | ver abaixo (`vm.py` + `ir.py`) |
| `Minify` / renomeação   | nomes novos e únicos (`cleanup.py`) |

### Cff (achatamento do fluxo de controle)

O `Cff` compila o programa inteiro para uma função
`container(pos, args, upvals, proxy, env)` com `while pos do <busca binária
nos ids de bloco> end`. Os helpers (`callFunction`, `pack`, `unpack`,
criadores de closure, alocador de upvalues...) têm nomes e ordem aleatórios,
então são reconhecidos **pela forma** do corpo. Cada bloco é traduzido para uma
IR de registradores; o salto (`pos = c and A or B`, inclusive as formas
espalhadas que o `for` numérico gera) é resolvido simbolicamente; as "células"
de upvalue (`upvals[id]`) voltam a ser variáveis locais capturadas.

### Vmify (VM de registradores)

Tudo o que o Prometheus randomiza por arquivo é recuperado sem executar nada:

* **protótipos**: `rebuild({{registros embaralhados}}, n, raiz)` é emulado;
* **chaves dos campos** (`code`, `constants`, `params`, `captures`,
  `children`...): inferidas pela forma dos dados;
* **permutação dos operandos** (slots 2..5): inferida pelos slots que cada
  instrução usa;
* **números dos opcodes** (56, embaralhados): cada handler da árvore de
  despacho do interpretador é normalizado e comparado com os templates dos
  handlers do Prometheus (`vm.HANDLERS`). Funciona tanto com o interpretador
  nativo (`Medium`) quanto com o interpretador também achatado pelo `Cff`
  (`Strong`), que é primeiro "desachatado".

O bytecode é então convertido para a mesma IR do Cff.

### Backend comum (`ir.py`)

* resolução de células (variáveis capturadas por closures);
* divisão de registradores em variáveis (teias def-uso);
* eliminação de código morto, propagação de constantes e *inlining* de
  temporários com verificação de ordem de avaliação e efeitos colaterais
  (indexação e aritmética podem chamar metamétodos, então são tratadas como
  efeitos);
* recuperação de `a and b` / `a or b`;
* estruturação do CFG em `if/elseif/else`, `while`, `repeat ... until`,
  `break` (com fallback para uma máquina de estados explícita se algum CFG
  não for estruturável);
* posicionamento de `local` respeitando escopo e laços;
* recuperação de `for i = a, b, c`, `for k, v in ...`, `local a, b = f()`,
  construtores de tabela, `obj:metodo()`, `local function`.

## Testes

`tests/roundtrip.py` ofusca arquivos com o Prometheus real, desofusca e
compara a saída dos dois programas:

```bash
python3 tests/roundtrip.py --prometheus /caminho/Prometheus --lua lua5.1
python3 tests/roundtrip.py --prometheus /caminho/Prometheus --presets Strong arquivo.lua
```

Resultado com os 32 testes executáveis do repositório do Prometheus × 6
presets: **182/192** — as 10 falhas são só `gc-temporaries` e
`function-environment-gc` (ver limitações). Em todos os casos do `Strong` a VM
foi devirtualizada. Tempo típico: < 1 s para `Weak`/`Cff`/`Vmify`, ~15 s para
`Medium`/`Strong` (a emulação dos decodificadores em Python domina).

## Limitações

* **Nomes locais** são perdidos na ofuscação; o resultado usa nomes gerados.
* **Blocos `do ... end`** que só limitavam escopo não são reconstruídos depois
  do `Cff`/`Vmify` (a variável vive até o fim do bloco externo). Isso não muda
  a lógica, mas muda quando o GC pode coletar um objeto — os dois testes do
  Prometheus que verificam exatamente isso (`gc-temporaries`,
  `function-environment-gc`) falham por esse motivo.
* `continue` (Luau) dentro de laços achatados não é recriado; o alvo é Lua 5.1.
* Steps opcionais fora dos presets (`ProxifyLocals`, `SplitStrings` com função
  customizada, `Watermark*`, `AddVararg`) não têm tratamento específico; o
  constant folding genérico ajuda em parte deles.
* Feito para a versão atual do Prometheus (a do zip enviado). Versões antigas,
  com a VM "IronBrew-like" do `Vmify` antigo, têm outro formato.

## Estrutura

```
prometheus_deobf/
  parser.py     lexer + parser Lua 5.1 com resolução de escopo
  printer.py    gerador de código
  luaast.py     AST
  fold.py       constant folding
  emulator.py   interpretador Lua sandbox (só para os decodificadores)
  emufold.py    ConstantArray / EncryptStrings / string pool / AntiTamper
  unwrap.py     WrapInFunction e beta-redução
  cff.py        lifter do Cff
  vm.py         devirtualizador da VM
  ir.py         IR, otimizações e estruturação
  cleanup.py    recuperações de alto nível e renomeação
  deobfuscate.py  pipeline (itera até não haver mais progresso)
```

Baseado na análise do código-fonte do Prometheus por Elias Oelschner,
https://github.com/prometheus-lua/Prometheus
