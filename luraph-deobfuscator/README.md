# luraph-deobfuscator

Duas abordagens complementares, ambas **sem executar nada no host** (tudo roda no emulador Luau em Python, sem arquivo/rede/OS):

| Ferramenta | Comando | O que faz |
|---|---|---|
| Desofuscador estático (Luraph v15.x) | `python -m luraph_deob in.lua -o out.lua` | Emula só o loader, executa a VM de forma abstrata e re-levanta o código. **Em andamento** (veja abaixo). |
| Dumper dinâmico / env logger | `python -m luraph_deob.dump in.lua -o out.lua` | Executa o script num ambiente Roblox simulado (proxies gravadores) e reescreve as interações observadas como Lua legível. Qualquer versão do Luraph, MoonSec V2/V3 e outros VMs. |

## Dumper dinâmico (`envlog.py`)

Registra `game:GetService`, `Instance.new`, leitura/escrita de propriedades, chamadas de método, `loadstring` (o chunk é salvo em `out.chunkN.lua` e executado sob o tracer), callbacks de eventos (`:Connect(function ... end)`), `task.spawn`, etc.

Limites inerentes a qualquer env logger (não são bugs):
* só aparece o que **executou**: ramos não tomados e `if`/`for` do script original não são reconstruídos;
* valores que só um servidor Roblox real produziria (resultado de `HttpGet`, filhos de `game`...) são proxies;
* `loadstring(game:HttpGet(url))()` é registrado, **não** buscado (sem rede).

Opções: `--timeout`, `--max-events`, `--no-callbacks`.

## Estrutura do desofuscador estático

`loader` (estágio 1) → `absvm` (estágio 2) → `lifter` → `structure` (CFG, propagação de constantes, `if`/`while`) → `postprocess`.
`structure.py` ainda **não** está ligado ao `pipeline.py`; ele tem teste de equivalência aleatória (`tests/test_structure.py`).

## Testes

`PYTHONPATH=. python3 -m unittest tests.test_structure tests.test_envlog`
