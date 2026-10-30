# Handoff — Amael Macroped

*Atualizado em 2026-10-30, versão publicada: **v1.3.0**.*

## Onde estamos

O app substitui por completo o `MINI_KEYBOARD.app` (x86/Rosetta) do fabricante, de forma nativa em Apple Silicon.

| Área | Estado |
|------|--------|
| Protocolo (gravar, ler, identificar, LED) | ✅ completo e documentado em `docs/PROTOCOL.md` |
| Hardware testado | ✅ `514C:8851`, 3 teclas + 1 knob — gravação/leitura byte a byte e teste físico aprovados |
| App SwiftUI | ✅ teclas/macros, mídia, mouse, knob, 3 camadas, LED, perfis JSON, ler do teclado, limpar tudo |
| Idiomas | ✅ pt-BR, English, Русский, 简体中文 (troca ao vivo) |
| Visual | ✅ design system do Purge, aparência Automático/Claro/Escuro |
| Ícone | ✅ Icon Composer: Padrão, Tom escuro, Translúcido, Tonalizado |
| CLI `macroped` | ✅ list, identify, read, write, write-default, example, monitor, raw |
| Distribuição | ✅ GitHub Releases, assinatura ad-hoc (sem notarização) |
| CI | ✅ `swift test` + build arm64 em `macos-latest` |

## Fatos do dispositivo que não estão óbvios no código

- A interface de configuração é a HID vendor (usage page `0xFF00`, relatórios de 65 bytes). Ela **não** exige
  permissão de Monitoramento de Entrada; a interface de teclado (`0x0001/0x06`) não é usada.
- A resposta da leitura (`FA`) tem o mesmo layout do registro de gravação, com marcador `0xFA`. O firmware devolve
  sempre 15 teclas + 9 slots de knob por camada e **não devolve o LED**.
- Multimídia: o app original grava contador `2`; a configuração de fábrica tinha `1`. Os dois funcionam.
- Gravar uma ação vazia (tipo 1, contador 0) limpa o slot — validado.
- Camadas: o teclado guarda as 3, mas o modelo testado não tem botão de camada e o gesto de troca **não foi
  descoberto**. O mantenedor preferiu deixar como está.
- O USB pode não enumerar (só energia, LED aceso) — reconectar/trocar cabo resolveu.
- Strings USB vazias/lixo (`USB Keyboardȉ`): o app limpa o nome; não há marca identificável (produto white label).

## Próximo passo combinado: aba "Ações no Mac"

Ideia aprovada pelo mantenedor para uma próxima sessão. IA não roda no chip (CH55x/CH57x é pequeno demais), então
a inteligência fica no Mac:

1. **No teclado:** a tecla recebe um atalho "livre" — preferir **F13–F20** (usages HID `0x68–0x6F`; o macOS
   reconhece até F20) ou o *hyper* ⌃⌥⇧⌘ + letra. O protocolo já suporta isso hoje.
2. **No Mac:** o app (ou um agente leve na barra de menus, iniciado com `SMAppService`) registra esses atalhos
   globais com `RegisterEventHotKey` (Carbon), que **não** exige permissão de Acessibilidade, e executa a ação ligada:
   - rodar um Atalho da Apple (`shortcuts run "<nome>"` ou `shortcuts://run-shortcut?name=`);
   - abrir app/URL;
   - IA sobre o texto selecionado: Apple Foundation Models (no dispositivo, macOS 26+) ou API de LLM com chave no
     Keychain. Ler a seleção exige simular ⌘C → **precisa de Acessibilidade**; considerar via Serviços do macOS.
3. **UI sugerida:** novo tipo de ação "Ação no Mac" no `SlotEditor`. Ao escolher, o app atribui automaticamente
   um F13–F20 livre ao slot, grava no teclado e guarda o mapeamento `tecla → ação` em
   `~/Library/Application Support/Amael Macroped/` (separado do perfil do dispositivo).
4. Seguir as regras de `CLAUDE.md`: textos nos 4 idiomas, tokens do `Theme/`, testes para qualquer lógica nova.

## Outras ideias em aberto

- Seletor manual de layout (firmwares que não respondem a `03 FB FB FB` hoje caem em 3 teclas + 1 knob).
- Modelo de *issue* no GitHub pedindo a saída de `macroped list` / `identify` para mapear outros modelos.
- Modelos de 16/21 teclas: o app original tem layouts `16add0`/`21add1`, mas a numeração de slots acima de 15
  é desconhecida — precisa de um aparelho para confirmar.
- Mostrar macros como sequência (`⌃ → ⌘ → C`) e avisar quando uma linha tiver só modificador.
- Bluetooth: só faz sentido em modelos *dual mode* configurados pelo cabo USB.
- Notarização Apple (exige conta de desenvolvedor paga) para eliminar o aviso do Gatekeeper.

## Arquivos locais (não versionados)

- `BASE_DRIVER_x86_MINI_KEYBOARD.app/` — app original, usado só como referência da engenharia reversa.
- `dist/` — builds, zips e backups da configuração do teclado do mantenedor
  (`backup-config-fabrica.json`, `backup-config-usuario.json`).
