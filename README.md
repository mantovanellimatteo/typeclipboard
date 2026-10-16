# TypeClipboard ⌨️📋

**Incolla digitando.** App per la barra dei menu di macOS che digita il contenuto della clipboard
simulando la tastiera, carattere per carattere.

Pensata per tutti i casi in cui il normale ⌘V non funziona:

- console web di VM (vSphere, Proxmox, Hyper-V, iDRAC/iLO, noVNC…)
- TeamViewer, VNC e altri desktop remoti
- schermata di login di Windows in console
- campi che bloccano l'incolla

È l'equivalente macOS di questo script AutoHotkey:

```autohotkey
^!v::
{
SendInput "{Raw}" A_Clipboard
}
```

## Funzionalità

- 🎯 **Scorciatoia globale personalizzabile** – predefinita **⌃⌥V**
- 🔤 **Keycode reali** – ogni carattere viene convertito nel tasto fisico del layout attivo (es. Italiano),
  con Shift/Option premuti davvero: funziona anche con le console remote che ignorano l'input Unicode
- 🌐 **Ripiego Unicode** per i caratteri non presenti nel layout (emoji ecc.)
- ↩️ A capo → Invio, tabulazione → Tab
- 🐢 **Ritardo tra i tasti** regolabile per console lente
- ⏱️ **Ritardo iniziale** e attesa del rilascio dei modificatori della scorciatoia
- ⛔ **Esc** per interrompere testi lunghi
- 🚀 Avvio automatico al login
- 🫥 Solo barra dei menu, nessuna icona nel Dock

## Requisiti

- macOS 13 Ventura o successivo (Apple Silicon o Intel)
- Per compilare: Xcode oppure Command Line Tools (`xcode-select --install`)

## Installazione

### Da release

1. Scarica `TypeClipboard-x.y.z.zip` dalla pagina [Releases](https://github.com/mantovanellimatteo/typeclipboard/releases).
2. Estrai e sposta `TypeClipboard.app` in `/Applications`.
3. L'app è firmata ad-hoc (non notarizzata): al primo avvio fai clic destro → **Apri**, oppure
   `xattr -dr com.apple.quarantine /Applications/TypeClipboard.app`.

### Da sorgente

```bash
git clone https://github.com/mantovanellimatteo/typeclipboard.git
cd typeclipboard
./build.sh
cp -R build/TypeClipboard.app /Applications/
open /Applications/TypeClipboard.app
```

## Primo avvio: permesso Accessibilità

Per inviare eventi tastiera, macOS richiede il permesso **Accessibilità**:

**Impostazioni di Sistema → Privacy e sicurezza → Accessibilità → abilita TypeClipboard**

La finestra Impostazioni dell'app mostra lo stato del permesso e un pulsante per aprire direttamente il pannello.

> [!NOTE]
> Con la firma ad-hoc, dopo ogni ricompilazione macOS può considerare l'app "nuova".
> Se la digitazione smette di funzionare, rimuovi TypeClipboard dalla lista Accessibilità e aggiungilo di nuovo.

## Uso

1. Copia un testo (⌘C).
2. Porta in primo piano la finestra di destinazione (console VM, TeamViewer…).
3. Premi **⌃⌥V** e rilascia i tasti: il testo viene digitato.
4. Premi **Esc** per interrompere.

Dall'icona ⌨️ nella barra dei menu → **Impostazioni…** puoi:

| Opzione | Default | Descrizione |
|---|---|---|
| Scorciatoia | ⌃⌥V | Clicca e premi la nuova combinazione (serve almeno ⌘, ⌃ o ⌥) |
| Ritardo tra i tasti | 10 ms | Aumentalo se la console remota perde caratteri |
| Ritardo iniziale | 300 ms | Attesa prima di iniziare a digitare |
| Avvia al login | off | Avvio automatico all'accesso |

## Limitazioni note

- Il layout di tastiera della macchina remota deve corrispondere a quello del Mac.
- I caratteri che sul layout attivo richiedono tasti morti (es. `~` su alcuni layout) usano il ripiego Unicode,
  che alcune console remote potrebbero ignorare.

## Struttura del progetto

```
Sources/TypeClipboard/
├── App.swift                  # entry point, menu bar, permessi
├── HotKeyManager.swift        # scorciatoia globale (Carbon)
├── KeyboardLayoutMapper.swift # carattere → tasto fisico del layout attivo
├── Typer.swift                # invio eventi CGEvent
└── SettingsView.swift         # impostazioni e registratore scorciatoia
Resources/Info.plist
build.sh                       # build + bundle .app + zip
VERSION                        # versione corrente (SemVer)
CHANGELOG.md
```

## Versioning

Il progetto segue il [Semantic Versioning](https://semver.org/lang/it/). Per rilasciare una nuova versione:

1. aggiorna `VERSION` e `CHANGELOG.md`;
2. `git commit -am "Release vX.Y.Z" && git tag vX.Y.Z && git push --follow-tags`;
3. `./build.sh` e allega `build/TypeClipboard-X.Y.Z.zip` alla release su GitHub.

## Licenza

MIT – vedi [LICENSE](LICENSE).
