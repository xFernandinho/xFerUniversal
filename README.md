# xFer Universal

Un script universal de Roblox con framework de UI modular, auto-actualización y funciones plug-and-play para la comunidad.

## ¿Qué incluye?
- `xfer.lua`: script principal monolítico listo para cargar en Roblox.
- Sistema de auto-actualización por comparación de versión local vs GitHub raw.
- UI dark + gold con drag-and-drop y tabs.
- Registro de features via `NovaFeatures.register(...)`.
- Guardado de configuración por juego y por identidad del proyecto.
- Soporte básico para `Noclip`, `Speed`, `Jump`, `Fly`, `Anti-AFK`, `ESP`, `Aimbot`, `Server Browser` y `Rejoin`.

## Cargar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.lua"))()
```

## Estructura principal

```text
xFerUniversal/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── xfer.version
├── xfer.lua
└── xFerUniversal/   (configuración persistente en el cliente)
```

## Configuración

La configuración se guarda dentro de la carpeta del cliente:

```text
xFerUniversal/
```

Se guarda como:

```text
xFerUniversal/<GameName>_<PlaceId>.json
```

## Actualizaciones

El script compara la versión local con la versión remota en:

```text
https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.version
```

Si existe una versión más nueva, intenta descargar y ejecutar la última versión.

## Soporte

- PC: compatible
- Móvil: compatible con UI responsive
- Executors con `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`: soporte completo
- Executors sin acceso a filesystem: modo UI + funciones sin persistencia

## Licencia

MIT
