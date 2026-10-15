# Jogo para o console Lupi (game jam de 1h)

## Regras da jam
- IA so pode ser usada para CODIGO. NUNCA gere, desenhe ou edite assets (PNG, sprites, mapas, sons).
- Assets vem de fora e ficam em src/ (ex: src/player/f1.png). So referencie os que existem.
- Mudancas pequenas e rapidas. Nao refatore o que ja funciona. Mantenha o jogo sempre rodando.

## Plataforma
- Lua 5.4. Tela 480x270, 60 FPS fixos (nao precisa de delta time).
- Entrada: src/game.lua, que define `update()`, chamada todo frame (logica + desenho).
- Dev: `make run` -> http://localhost:3000/webgame/game.html (rebuild ao salvar).
- PNG: max 512x512, ate 256 cores. Viram `Sprites.<pasta>["<nome>"]` via `require("sprites")`.
- Mapas Tiled (.json) viram script Lua.

## API (namespace ui)
Cores sao indices de paleta 0-255. `ui.palset(i, bgr555)` define a cor.
- ui.cls(cor)
- ui.rect(x1,y1,x2,y2,cor) / ui.rectfill(x1,y1,x2,y2,cor)
- ui.draw_rect(x,y,w,h,filled,cor)
- ui.circfill(x,y,r,cor) / ui.draw_circle(cx,cy,r,filled,cor,border,border_cor)
- ui.trisfill(x1,y1,x2,y2,x3,y3,cor)
- ui.line(x1,y1,x2,y2,cor)
- ui.print(texto,x,y,cor)  -- evite acentos
- ui.spr(sprite,x,y,flipped) / ui.tile(tileset,idx,x,y) / ui.map(layer,camx,camy)
- ui.camera(x,y) (ui.camera() reseta) / ui.clip(x,y,w,h) / ui.fillp(...)
- ui.btn(botao,pad) segurado / ui.btnp(botao,pad) recem-apertado
  Botoes: UP DOWN LEFT RIGHT BTN_Z BTN_Q BTN_E BTN_F BTN_G
- ui.log(msg) / ui.mid(a,b,c)
- NAO existe API de som.

## Boas praticas
- Nao crie tabelas dentro de update() (use pools pre-alocados) para evitar engasgos de GC.
- Toda config/balanceamento no topo do arquivo.
