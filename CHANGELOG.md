# Changelog

## [1.0.0] - 2026-10-22

### Added
- Script principal `xfer.lua`
- Sistema de auto-actualización con `xfer.version`
- UI dark + gold con drag-and-drop
- Soporte de tabs e interfaz responsive
- Registro de features con `NovaFeatures.register(...)`
- Base de features para:
  - Noclip
  - Speed
  - Jump
  - Fly
  - Anti-AFK
  - ESP
  - Aimbot
  - Server Browser
  - Rejoin
- Persistencia por juego usando `xFerUniversal/`

### Improved
- Mejorado manejo de errores con `pcall`
- Uso de `makefolder`/`isfolder` para evitar fallos en ejecutores que no tienen la carpeta creada
- Compatibilidad con mobile y PC
- Fallback silencioso si no hay soporte para filesystem

### Changed
- Reestructuración interna del script para separar claramente Core, UI y Features
- API pública `createNovaUI(options)`
- Reducción de lógica duplicada y mejor limpieza de listeners
