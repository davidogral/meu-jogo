# Jogo para o console Lupi (game jam de 1h)

## Regras da jam
- IA so pode ser usada para CODIGO. NUNCA gere, desenhe ou edite assets (PNG, sprites, mapas, sons).
- Assets vem de fora e ficam em src/ (ex: src/player/f1.png). So referencie os que existem.
- Mudancas pequenas e rapidas. Nao refatore o que ja funciona. Mantenha o jogo sempre rodando.

## Plataforma
- Lua 5.5 (lupinho 1.1.0; `for` vars sao read-only, `global` e palavra reservada). Tela 480x270, 60 FPS fixos (nao precisa de delta time).
- Entrada: src/game.lua, que define `update()`, chamada todo frame (logica + desenho).
- Dev: container Docker lupi-sdk na porta 8765 -> http://localhost:8765/webgame/game.html (rebuild ao salvar src/).
- Commit: .gitignore ignora src/, entao SEMPRE `git add -f src/ CLAUDE.md`.
- PNG: max 512x512, ate 256 cores. O codec gera palette.lua (`Palette`) e os sprites usam os indices 0..#Palette-1:
  aplique `Palette` e ponha as cores do jogo DEPOIS (BASE = #Palette), senao os sprites ficam com cor errada.
- Naves: src/naves/sparrow-cream.png e sparrow-slate.png (Cozy Space Ships, Bramble & Byte, CC-BY 4.0, credito no titulo).
- Asteroides: src/asteroides/meteorGrey_{med1,small1,tiny1}.png (Space Shooter Redux, Kenney, CC0), copiados sem alteracao.
  Evento CHUVA DE ASTEROIDES usa esses sprites; tamanhos ficam em AST_TIPOS (o console nao informa width).
  Girados 90 graus horario (apontam para a direita) a pedido do usuario em 2026-10-15; a CPU e espelhada no codigo. Viram `Sprites.<pasta>["<nome>"]` via `require("sprites")`.
- Mapas Tiled (.json) viram script Lua.

## DOIS FIRMWARES (importante)
- SDK lupinho 1.1.0 (Docker, porta 8765) != console real / docs https://lupi.api.br/docs/.
- Console: LEFT=0 RIGHT=1 UP=2 DOWN=3 BTN_Z=4(B) BTN_X=5(X) BTN_F=12(Y) BTN_G=13(A) BTN_Q=14(L) BTN_E=15(R),
  sem START/SELECT; btn retorna false ou numero 0-255; as docs dizem cor RGB555, MAS o lupi-codec oficial gera BGR555 e o primeiro-jogo usa direto -> use BGR555; tem ui.circ, ui.stat, sfx.*.
- Todo frame: ui.clip(0,0,480,270), ui.camera(0,0) e reaplicar a paleta (padrao do primeiro-jogo oficial).
- No console `Sprites.<pasta>[nome]` NAO tem width/height (so no SDK): guarde o tamanho do PNG numa constante.
- NAO use ui.btnp no console: ele repete enquanto segura (estilo PICO-8; pausa despausava sozinha). Detecte o toque com ui.btn (agora e nao no frame anterior), 1x por frame.
- Lua: no maximo 200 locais ativos no chunk principal (erro 'too many local variables'). Agrupe modulos em blocos do...end e exporte so o necessario.
- Console: ui.btn pode devolver numero (pressao); trate 0 como NAO apertado (`v == true or v > 0`).
- Console: mantenha poucos comandos de desenho por frame (tiros em codigo, sem sprite de projetil). A PALETA TEM QUE SER INTEIRA TODO FRAME: em fatias a tela piscou preto no console.
- Evite ui.clip por objeto todo frame no console (ex.: animar spritesheet recortando com clip): travou o jogo com muitos tiros. Prefira desenho em codigo ou 1 sprite por quadro.
- Detectar com `BTN_X ~= nil`. NUNCA usar numero cru de botao no console (erro = tela preta).
- src/game.lua e um loader que roda src/jogo.lua com pcall e mostra o erro NA TELA.
- Deploy no console: fork github.com/davidogral/primeiro-jogo (de lupi-org-br/primeiro-jogo), com game.lua + jogo.lua na raiz.
  Copie os dois arquivos de src/ para ../primeiro-jogo e de push la tambem.

## API do SDK 1.1.0 (namespace ui)
Cores sao indices de paleta 0-255. `ui.palset(i, bgr555)` define a cor: bits 0-4 = R, 5-9 = G, 10-14 = B
(0x001F vermelho, 0x03E0 verde, 0x7C00 azul). Indice 0 = TRANSPARENTE (aparece preto).
- ui.cls(cor)
- ui.rect(x1,y1,x2,y2,cor) / ui.rectfill(x1,y1,x2,y2,cor)
- ui.draw_rect(x,y,w,h,filled,cor)
- ui.circfill(x,y,r,cor) / ui.draw_circle(cx,cy,r,filled,cor,border,border_cor)
- ui.trisfill(x1,y1,x2,y2,x3,y3,cor)
- ui.line(x1,y1,x2,y2,cor)
- ui.print(texto,x,y,cor)  -- fonte 5x8, avanco 6px/char (centro: x = W/2 - #txt*3); so ASCII 32-126
- ui.spr(sprite,x,y,flipped) / ui.tile(tileset,idx,x,y) / ui.map(layer,camx,camy)
- ui.camera(x,y) (ui.camera() reseta) / ui.clip(x,y,w,h) / ui.fillp(...)
- ui.btn(botao,pad) segurado / ui.btnp(botao,pad) recem-apertado
  Botoes: UP DOWN LEFT RIGHT BTN_Z BTN_Q BTN_E BTN_F BTN_G
  Teclado (sempre checado, IGNORA o pad): UP/LEFT/DOWN/RIGHT = W/A/S/D (setas NAO funcionam),
  BTN_Z = K (RIGHT_FACE_DOWN; o C define BTN_Z duas vezes e esta vence), BTN_Q = L, BTN_E = M,
  BTN_F = G, BTN_G = H. Tecla Z nao faz nada. Console tem 1 controle = pad 0.
- update(frame) recebe o contador de frames como argumento.
- ui.log(msg) / ui.mid(a,b,c)
- NAO existe API de som.

## Boas praticas
- Desempenho: textos montados 1x no load (sem `..` no update), pools fixos (24 tiros, 40 particulas, 10 asteroides),
  GC geracional; medidor FPS/MEM na tela de pausa (ui.stat no console). Lixo medido: ~0.3 KB a cada 200 frames.
- Nao crie tabelas dentro de update() (use pools pre-alocados) para evitar engasgos de GC.
- Toda config/balanceamento no topo do arquivo.
