# CLAUDE.md

Guia para quem (pessoa ou agente) for trabalhar neste repositório. Estado atual e próximos passos:
[docs/HANDOFF.md](docs/HANDOFF.md). Protocolo do dispositivo: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Comandos

```bash
swift build                        # debug
swift test                         # testes do protocolo (MacropedKitTests)
scripts/build-app.sh               # dist/Amael Macroped.app + dist/AmaelMacroped-<VERSION>.zip (arm64)
VERSION=1.4.0 scripts/build-app.sh # define a versão do bundle/zip
scripts/build-app.sh --universal   # arm64 + x86_64
.build/debug/macroped list|identify|read|write <json>|monitor|raw <hex…>
```

Variáveis de depuração do app (não exigem permissão de gravação de tela):
`AMAEL_SNAPSHOT=<png>` salva a janela em PNG ~1,8 s após abrir; `AMAEL_SNAPSHOT_SETTINGS=1` abre e fotografa
os Ajustes; `AMAEL_LANG=pt-BR|en|ru|zh-Hans`; `AMAEL_APPEARANCE=light|dark`.

## Arquitetura

- `Sources/MacropedKit` — sem UI. `MacropedProtocol` (codifica/decodifica relatórios), `Model` (Slot, KeyAction,
  DeviceProfile…), `Coding` (JSON legível dos perfis), `HIDKeys` (tabela HID + kVK→HID + texto→acordes),
  `MacropedDevice` (IOKit: escolhe a interface vendor 0xFF00 de 65 bytes, thread própria de run loop para entrada).
- `Sources/AmaelMacroped` — SwiftUI. `AppModel` (estado, E/S em fila de trabalho, status como `StatusMessage`),
  views (`ContentView`, `PadView`, `SlotEditor`, `SettingsView`), `Theme/`, `Localization/`.
- `Sources/MacropedCLI` — CLI em pt-BR.
- `Resources/AmaelMacroped.icon` — ícone do Icon Composer, compilado pelo `actool` no `build-app.sh`.

## Regras do projeto

- **Textos da interface** passam sempre por `Strings` (`Localization/`). Ao adicionar um campo, traduza nos
  4 arquivos (`Strings+Portuguese/English/Russian/Chinese.swift`) — o compilador falha se faltar.
  Mensagens de status/erro são `StatusMessage` (renderizadas no idioma atual), nunca `String` pronta.
- **Visual** só com tokens de `Theme/` (design system adaptado do Purge): `AppColors` por função, `AppStyle.Typography`
  (fonte Onest), `AppStyle.Spacing`/`Radius`, `.buttonStyle(.app(...))`. Ações são pílulas; controles que guardam
  valor (dropdown, segmentado, campo) usam retângulo `Radius.md`. Cards: `Card` com hairline de 0,5 pt, sem sombra.
  Uma ação `.primary` por tela. Exceção: `LEDColor.swatch` mostra a cor física do LED.
- **Protocolo**: qualquer mudança em `MacropedProtocol` precisa de teste em `ProtocolTests` e, se possível, de
  verificação no hardware (gravar → `read` → comparar). Antes de gravar num teclado real, faça backup com
  `macroped read > backup.json` e restaure ao final.
- **Nunca** versionar `BASE_DRIVER_x86_MINI_KEYBOARD.app/` (software proprietário do fabricante, só referência) nem `dist/`.
- Créditos de terceiros ficam em `THIRD_PARTY_NOTICES.md` e no cabeçalho dos arquivos adaptados (MIT exige).
- Converse com o mantenedor em **português do Brasil**.

## Release

1. Atualize `CHANGELOG.md`.
2. `swift test` e `VERSION=x.y.z scripts/build-app.sh`; confira `codesign --verify --deep --strict "dist/Amael Macroped.app"`.
3. Commit, `git push`, `gh release create vx.y.z dist/AmaelMacroped-x.y.z.zip --repo amondf/amael-macroped`.
4. Confira o CI (`.github/workflows/ci.yml`: testes + build arm64).
