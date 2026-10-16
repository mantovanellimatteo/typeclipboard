# Changelog

Tutte le modifiche rilevanti del progetto sono documentate qui.
Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/)
e il progetto adotta il [Semantic Versioning](https://semver.org/lang/it/).

## [Unreleased]

## [0.2.0] - 2026-10-16

### Aggiunto
- Design **Liquid Glass** nativo per macOS Tahoe (`.glassEffect`, capsule interattive e `Glass.regular`) con fallback traslucido per versioni precedenti.
- Card di stato in cima al menu della barra di sistema con anteprima live degli appunti, conteggio caratteri (`NSMenuItemBadge`) e avanzamento digitazione in tempo reale.
- Registratore scorciatoia ridisegnato con singoli keycap in vetro (`⌃` `⌥` `V`).
- Selettore rapido dei profili di digitazione (*Rapido*, *Bilanciato*, *Console remota lenta*) e cursori continui per i ritardi.

### Modificato
- Finestra Impostazioni full-bleed traslucida con barra del titolo integrata e sezioni fluttuanti in vetro.
- Icone SF Symbols nel menu rese esplicitamente visibili su macOS Tahoe (`preferredImageVisibility = .visible`) e scorciatoie mostrate nello slot nativo `keyEquivalent`.

## [0.1.0] - 2026-10-16

### Aggiunto
- App per la barra dei menu che digita il contenuto testuale della clipboard simulando la tastiera.
- Scorciatoia globale personalizzabile (predefinita ⌃⌥V).
- Invio di keycode reali del layout attivo (Shift/Option premuti fisicamente) con ripiego Unicode.
- Gestione di a capo (Invio) e tabulazioni (Tab).
- Ritardo tra i tasti e ritardo iniziale configurabili.
- Interruzione della digitazione con Esc o dal menu.
- Avvio automatico al login.
- Verifica e richiesta del permesso Accessibilità.

[Unreleased]: https://github.com/mantovanellimatteo/typeclipboard/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mantovanellimatteo/typeclipboard/releases/tag/v0.2.0
[0.1.0]: https://github.com/mantovanellimatteo/typeclipboard/releases/tag/v0.1.0
