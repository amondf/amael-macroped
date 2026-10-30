# Protocolo HID do Mini Keyboard (CH57x / "MINI_KEYBOARD")

Documento obtido por engenharia reversa (análise estática) do utilitário oficial
x86_64 `MINI_KEYBOARD.app` (Qt 5.12 + hidapi 0.12), com o objetivo exclusivo de
interoperabilidade. Nenhum código do fabricante é redistribuído neste projeto.

## Identificação USB

| Campo      | Valores                                                                |
|------------|------------------------------------------------------------------------|
| Vendor ID  | `0x1189` (principal), `0x514C` (alternativo)                           |
| Product ID | `0x8840`, `0x8842`, `0x8830`, `0x8831`, `0x8832`, `0x8833`, `0x8850`, `0x8851` |

O app oficial abre a interface HID cujo `interface_number == 0` *ou* qualquer
interface que aceite relatórios de saída com Report ID `0x03`.

## Transporte

* Todos os comandos são **Output Reports de 65 bytes**: `byte[0] = 0x03`
  (Report ID) + 64 bytes de payload.
* Respostas chegam como Input Reports de 64 bytes (também com Report ID `0x03`).

## Comandos

| Comando                 | Bytes (após `0x03`)              | Descrição                                   |
|-------------------------|----------------------------------|---------------------------------------------|
| Identificar             | `FB FB FB`                       | Resposta: `byte[2]` = nº de teclas, `byte[3]` = nº de knobs, `byte[4]` = info extra |
| Ler camada              | `FA <nTeclas> <nKnobs> <camada>` | O dispositivo responde com um registro por slot (camada 1..3) |
| Gravar slot             | registro de 50 bytes (abaixo)    | Um relatório por slot alterado              |
| Confirmar (commit)      | `FD FE FF`                       | Enviado ao final de cada camada; o app oficial espera 1 s depois |

## Registro de slot (50 bytes)

| Offset | Significado                                                              |
|--------|--------------------------------------------------------------------------|
| 0      | `0xFD` (tecla/knob) ou `0xFE` (LED)                                      |
| 1      | Slot (ver tabela abaixo); `0xB0` para LED                                |
| 2      | Camada (1..3)                                                            |
| 3      | Tipo: `1` teclado, `2` multimídia, `3` mouse, `5` atraso, `8` LED        |
| 4–5    | Atraso em ms (little-endian) — somente tipo `5`                          |
| 6–8    | `0x00`                                                                   |
| 9      | Contador de entradas                                                     |
| 10..49 | Dados (dependem do tipo)                                                 |

### Slots

| Slot          | Elemento                                   |
|---------------|--------------------------------------------|
| `0x01`–`0x0F` | Teclas K1–K15                              |
| `0x10 + 3k`   | Knob *k* girando para a esquerda (anti-horário) |
| `0x11 + 3k`   | Knob *k* pressionado                       |
| `0x12 + 3k`   | Knob *k* girando para a direita (horário)  |

### Tipo 1 — Teclado (macro de até 18 acordes)

`byte[9]` = número de acordes. Para cada acorde *i*:
`byte[10 + 2i]` = máscara de modificadores, `byte[11 + 2i]` = HID usage (página 0x07).

Modificadores: `0x01` Ctrl, `0x02` Shift, `0x04` Alt/Option, `0x08` Win/Command,
`0x10` Ctrl dir., `0x20` Shift dir., `0x40` Alt dir., `0x80` Win/Command dir.

### Tipo 2 — Multimídia

`byte[9] = 2`, `byte[10..11]` = código Consumer Page (little-endian).
Exemplos: `0x00E9` Vol+, `0x00EA` Vol−, `0x00E2` Mudo, `0x00CD` Play/Pause,
`0x00B5` Próxima, `0x00B6` Anterior, `0x00B7` Stop, `0x006F`/`0x0070` Brilho ±.

### Tipo 3 — Mouse

`byte[9] = 1`, `byte[10]` = modificadores de teclado, `byte[11]` = botões
(`1` esq., `2` dir., `4` meio), `byte[14]` = roda (`+1` / `-1` como int8).

### LED (tipo 8)

`FE B0 <camada> 08 00 00 00 00 00 01 00 <(cor << 4) | modo>`

* Modo: `0`–`5` (efeitos do firmware; `0` = desligado).
* Cor: `1` vermelho, `2` laranja, `3` amarelo, `4` verde, `5` ciano, `6` azul, `7` roxo.

## Resposta da leitura (`FA`)

Para cada slot o firmware devolve um Input Report com o mesmo layout do registro de gravação, mas com
o marcador `0xFA` no lugar de `0xFD`. Ele sempre devolve os 15 slots de tecla + 9 de knob (24 relatórios
por camada), independentemente do modelo físico, e **não** devolve a configuração do LED.

Capturado de um `514C:8851` (3 teclas + 1 knob), camada 1, configuração de fábrica:

```
← 03 fa 01 01 01 00 00 00 00 00 01 01 50 …   K1: Ctrl + ←
← 03 fa 02 01 01 00 00 00 00 00 01 01 4f …   K2: Ctrl + →
← 03 fa 03 01 01 00 00 00 00 00 01 00 44 …   K3: F11
← 03 fa 10 01 02 00 00 00 00 00 01 ea 00 …   knob ↺: Volume −
← 03 fa 11 01 02 00 00 00 00 00 01 e2 00 …   knob ●: Mudo
← 03 fa 12 01 02 00 00 00 00 00 01 e9 00 …   knob ↻: Volume +
```

Resposta da identificação: `← 03 fb 03 01 …` (3 teclas, 1 knob).

## Sequência de gravação

```
para cada camada alterada:
    para cada slot alterado:  send(03 + registro)
    send(03 FD FE FF)
    aguardar ~1 s
```
