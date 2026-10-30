import Foundation
import MacropedKit

let usage = """
Amael Macroped — CLI

Uso: macroped <comando> [argumentos]

  list                      Lista as interfaces HID do mini teclado
  identify                  Pergunta ao firmware quantas teclas/knobs existem
  read                      Lê a configuração gravada (JSON na saída padrão)
  write <perfil.json>       Grava um perfil no dispositivo
  write-default             Grava o perfil padrão (⌘C ⌘V ⌘Z + volume no knob)
  example                   Imprime o perfil padrão em JSON (ponto de partida)
  monitor [segundos]        Mostra os relatórios HID recebidos (depuração)
  raw <hex> [hex ...]       Envia um relatório cru, ex.: raw 03 fb fb fb
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
}()

func openDevice() -> MacropedDevice {
    do { return try MacropedDevice.open() } catch { fail(error.localizedDescription) }
}

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { print(usage); exit(0) }
args.removeFirst()

switch command {
case "list":
    let list = MacropedDevice.list()
    if list.isEmpty { fail(MacropedError.notFound.localizedDescription) }
    list.forEach { print($0) }

case "identify":
    let dev = openDevice()
    print("Interface: \(dev.info)")
    if let layout = dev.identify() {
        print("Teclas: \(layout.keys)  Knobs: \(layout.knobs)")
    } else {
        print("O firmware não respondeu ao comando de identificação.")
    }

case "read":
    let dev = openDevice()
    let layout = dev.identify() ?? .threeKeysOneKnob
    do {
        let (profile, n) = try dev.readProfile(layout: layout)
        FileHandle.standardError.write("\(n) relatórios recebidos\n".data(using: .utf8)!)
        print(String(data: try encoder.encode(profile), encoding: .utf8)!)
    } catch { fail(error.localizedDescription) }

case "write", "write-default":
    let profile: DeviceProfile
    if command == "write" {
        guard let path = args.first else { fail("Informe o arquivo JSON do perfil.") }
        do {
            profile = try JSONDecoder().decode(DeviceProfile.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        } catch { fail("Perfil inválido: \(error)") }
    } else {
        profile = .defaultProfile()
    }
    let dev = openDevice()
    do {
        try dev.write(profile) { p in
            FileHandle.standardError.write(String(format: "\rGravando… %3.0f%%", p * 100).data(using: .utf8)!)
        }
        FileHandle.standardError.write("\nConcluído.\n".data(using: .utf8)!)
    } catch { fail("\n" + error.localizedDescription) }

case "example":
    print(String(data: try encoder.encode(DeviceProfile.defaultProfile()), encoding: .utf8)!)

case "monitor":
    let seconds = Double(args.first ?? "") ?? 10
    let dev = openDevice()
    print("Interface: \(dev.info)\nEscutando por \(Int(seconds)) s…")
    dev.onInputReport = { print("← \(hex($0))") }
    Thread.sleep(forTimeInterval: seconds)

case "raw":
    let bytes = args.compactMap { UInt8($0.replacingOccurrences(of: "0x", with: ""), radix: 16) }
    guard bytes.count == args.count, !bytes.isEmpty else { fail("Bytes hexadecimais inválidos.") }
    let dev = openDevice()
    dev.onInputReport = { print("← \(hex($0))") }
    var report = [UInt8](repeating: 0, count: MacropedProtocol.reportLength)
    report.replaceSubrange(0..<min(bytes.count, report.count), with: bytes.prefix(report.count))
    print("→ \(hex(report))")
    do { try dev.send(report) } catch { fail(error.localizedDescription) }
    Thread.sleep(forTimeInterval: 0.5)

default:
    print(usage)
    exit(1)
}
