-- DUELO CORINGA - LUPI (480x270 @ 60fps)  -- tema da jam: FALHA NO SISTEMA
-- 1 jogador vs CPU. Teclado: WASD move, K atira (BTN_Z = botao de baixo do controle).
-- Eventos aleatorios (aviso -> efeito) mudam as regras. O principal: INVERSAO.
-- Para adaptar ao tema da jam: escolha/edite um tema em TEMAS e troque TEMA_ATUAL.

-- ================= CONFIG =================
local TEMA_ATUAL = "falha"    -- falha | padrao | espaco | faroeste | magia
-- Input (lupinho 1.1.0): BTN_Z = GAMEPAD RIGHT_FACE_DOWN = tecla K; direcional = WASD.
-- O teclado e checado ignorando o pad, e o console tem 1 controle (pad 0).
local PAD1 = 0
local ACAO = BTN_Z
local VIDAS = 3
local VEL, VEL_TIRO, RECARGA = 3, 6, 18
local AVISO_FRAMES = 90                       -- 1.5s de aviso
local INTERVALO_MIN, INTERVALO_MAX = 360, 720 -- 6s a 12s entre eventos

-- ================= CPU (IA por regras) =================
-- reacao: frames entre decisoes | erro: +-px no Y mirado | desvio: chance de fugir de tiro
local DIFICULDADES = {
  facil   = { nome = "FACIL",   reacao = 30, erro = 40, desvio = 0.2 },
  medio   = { nome = "MEDIO",   reacao = 15, erro = 20, desvio = 0.5 },
  dificil = { nome = "DIFICIL", reacao = 6,  erro = 6,  desvio = 0.8 },
}
local ORDEM_DIF = { "facil", "medio", "dificil" }
local DIF_INICIAL = 2
local AJUSTE = 0.15          -- adaptativo: +-15% por vida perdida a favor de quem perde
local FAIXA = 0.3            -- adaptativo nunca sai de base*(1-FAIXA)..base*(1+FAIXA)
local CONFUSAO = 30          -- frames que a CPU anda errado no inicio do "inverte"
local ALINHADO = 10          -- px de diferenca no Y para a CPU considerar que esta na mira

-- ================= PALETA =================
local PAL = { 0x0000, 0x7FFF, 0x001F, 0x7C00, 0x03FF, 0x294A, 0x7C1F, 0x03E0, 0x0C63, 0x01BF }
for i = 1, #PAL do ui.palset(i - 1, PAL[i]) end
local PRETO, BRANCO, VERM, AZUL, AMAR, CINZA, ROXO, VERDE, ESCURO, LARANJA = 0,1,2,3,4,5,6,7,8,9

local W, H = 480, 270
local MEIO = W / 2

-- ================= EVENTOS =================
local EVENTOS = {
  inverte = { nome = "INVERTIDO", cor = ROXO,    dur = 300, inv = true },
  turbo   = { nome = "TURBO",     cor = LARANJA, dur = 240, vel = 2 },
  lama    = { nome = "LENTO",     cor = CINZA,   dur = 240, vel = 0.4 },
  rajada  = { nome = "RAJADA",    cor = VERDE,   dur = 240, rec = 0.3, tiro = 1.5 },
}
for k, e in pairs(EVENTOS) do e.id = k end

-- ================= TEMAS =================
local TEMAS = {
  falha = {
    titulo = "FALHA NO SISTEMA", nome1 = "NAVE", nome2 = "VIRUS.EXE",
    cor1 = VERDE, cor2 = VERM, fundo_cor = PRETO, fundo = "estrelas", glitch = true,
    forma = "nave", tiro_forma = "quad", aviso = "ERRO CRITICO DETECTADO",
    vitoria = " VENCEU!", eventos = { "inverte", "inverte", "turbo", "lama", "rajada" },
    nomes = { inverte = "CONTROLES CORROMPIDOS", turbo = "OVERCLOCK", lama = "LAG", rajada = "BUFFER OVERFLOW" },
  },
  padrao = {
    titulo = "DUELO INVERTIDO", nome1 = "VOCE", nome2 = "CPU",
    cor1 = AZUL, cor2 = VERM, fundo_cor = PRETO, fundo = "nada",
    forma = "quad", tiro_forma = "quad", aviso = "!! ATENCAO !!",
    vitoria = " VENCEU!", eventos = { "inverte", "inverte", "turbo", "rajada" },
  },
  espaco = {
    titulo = "GUERRA ORBITAL", nome1 = "NAVE A", nome2 = "NAVE B",
    cor1 = VERDE, cor2 = ROXO, fundo_cor = PRETO, fundo = "estrelas",
    forma = "tri", tiro_forma = "circ", aviso = "ANOMALIA GRAVITACIONAL",
    vitoria = " DOMINA A ORBITA!", eventos = { "inverte", "inverte", "lama", "turbo" },
  },
  faroeste = {
    titulo = "DUELO AO SOL", nome1 = "XERIFE", nome2 = "BANDIDO",
    cor1 = AMAR, cor2 = VERM, fundo_cor = ESCURO, fundo = "chao",
    forma = "quad", tiro_forma = "quad", aviso = "TEMPESTADE DE AREIA",
    vitoria = " E O MAIS RAPIDO!", eventos = { "inverte", "inverte", "rajada", "lama" },
  },
  magia = {
    titulo = "DUELO ARCANO", nome1 = "MAGO", nome2 = "BRUXA",
    cor1 = AZUL, cor2 = ROXO, fundo_cor = PRETO, fundo = "estrelas",
    forma = "circ", tiro_forma = "circ", aviso = "FEITICO DO CAOS",
    vitoria = " VENCEU O DUELO!", eventos = { "inverte", "inverte", "turbo", "rajada" },
  },
}
local T = TEMAS[TEMA_ATUAL]

-- ================= ESTADO =================
local estado = "titulo"
local dif_idx, dif, hud2 = DIF_INICIAL, nil, ""
local frame, shake, vencedor, players
local fase, timer, evento, prox_evento

local MAX_TIROS, MAX_PART = 20, 40
local tiros, parts = {}, {}
for i = 1, MAX_TIROS do tiros[i] = { ativo = false, x = 0, y = 0, dir = 0, dono = 0, v = 0 } end
for i = 1, MAX_PART do parts[i] = { vida = 0, x = 0, y = 0, vx = 0, vy = 0, cor = 0 } end

local estrelas = {}
for i = 1, 40 do estrelas[i] = { x = math.random(0, W), y = math.random(0, H), v = math.random(1, 3) } end

-- ================= UTIL =================
local function apertou(b) return ui.btnp(b, PAD1) end
local function centro(txt, y, cor)
  ui.print(txt, math.floor(W / 2 - #txt * 3), y, cor)
end

local function nome_ev(e) return (T.nomes and T.nomes[e.id]) or e.nome end

local function mod(campo)
  if fase == "ativo" and evento[campo] then return evento[campo] end
  return 1
end

local function explode(x, y, cor, n)
  for i = 1, MAX_PART do
    local p = parts[i]
    if p.vida <= 0 then
      p.vida, p.x, p.y, p.cor = 20 + math.random(0, 15), x, y, cor
      p.vx, p.vy = math.random(-30, 30) / 10, math.random(-30, 30) / 10
      n = n - 1
      if n <= 0 then return end
    end
  end
end

local function forma(f, x, y, w, h, cor, dir)
  if f == "tri" then
    if dir == 1 then ui.trisfill(x, y, x, y + h, x + w, y + h / 2, cor)
    else ui.trisfill(x + w, y, x + w, y + h, x, y + h / 2, cor) end
  elseif f == "nave" then
    local tras, ponta = dir == 1 and x or x + w, dir == 1 and x + w or x
    ui.trisfill(tras, y, tras, y + h, ponta, y + h / 2, cor)
    local mx = dir == 1 and x - 4 or x + w
    if (frame // 4) % 2 == 0 then
      ui.rectfill(mx, y + 2, mx + 4, y + 5, LARANJA); ui.rectfill(mx, y + h - 5, mx + 4, y + h - 2, LARANJA)
    end
    ui.circfill(x + w / 2, y + h / 2, 2, BRANCO)
  elseif f == "circ" then
    ui.circfill(x + w / 2, y + h / 2, w / 2, cor)
  else
    ui.rectfill(x, y, x + w, y + h, cor)
  end
end

-- ================= LOGICA =================
local function sorteia_evento()
  local lista = T.eventos
  prox_evento = EVENTOS[lista[math.random(1, #lista)]]
end

local function novo_player(id, x, cor, dir)
  return { id = id, x = x, y = H / 2 - 8, w = 16, h = 16, cor = cor,
           dir = dir, vidas = VIDAS, recarga = 0, hit = 0,
           -- so a CPU usa: parametros atuais da IA e estado da decisao
           cpu = id == 2, reacao = 0, erro = 0, desvio = 0, cont = 0, alvo_y = H / 2 - 8, quer_atirar = false }
end

local function reset()
  dif = DIFICULDADES[ORDEM_DIF[dif_idx]]
  hud2 = T.nome2 .. " [" .. dif.nome .. "]"
  players = { novo_player(1, 30, T.cor1, 1), novo_player(2, W - 46, T.cor2, -1) }
  local c = players[2]
  c.reacao, c.erro, c.desvio = dif.reacao, dif.erro, dif.desvio
  for i = 1, MAX_TIROS do tiros[i].ativo = false end
  for i = 1, MAX_PART do parts[i].vida = 0 end
  frame, shake, vencedor = 0, 0, nil
  fase, timer, evento = "normal", math.random(INTERVALO_MIN, INTERVALO_MAX), nil
  sorteia_evento()
end

local function atualiza_eventos()
  timer = timer - 1
  if timer > 0 then return end
  if fase == "normal" then
    fase, timer = "aviso", AVISO_FRAMES
  elseif fase == "aviso" then
    evento, fase, timer = prox_evento, "ativo", prox_evento.dur
    shake = 10
  else
    local vmin = math.min(players[1].vidas, players[2].vidas)
    local f = 0.5 + 0.5 * (vmin / VIDAS)
    fase, timer, evento = "normal", math.floor(math.random(INTERVALO_MIN, INTERVALO_MAX) * f), nil
    sorteia_evento()
  end
end

local function atirar(p)
  for i = 1, MAX_TIROS do
    local t = tiros[i]
    if not t.ativo then
      t.ativo, t.dono, t.dir = true, p.id, p.dir
      t.v = VEL_TIRO * mod("tiro")
      t.x = p.x + (p.dir == 1 and p.w or -5)
      t.y = p.y + p.h / 2 - 2
      return
    end
  end
end

-- Dificuldade adaptativa: perdeu_cpu=true -> CPU melhora; false -> CPU piora. Nunca sai da faixa.
local function ajusta_ia(perdeu_cpu)
  local c = players[2]
  local f = perdeu_cpu and (1 - AJUSTE) or (1 + AJUSTE)
  c.reacao = ui.mid(dif.reacao * (1 - FAIXA), c.reacao * f, dif.reacao * (1 + FAIXA))
  c.erro   = ui.mid(dif.erro * (1 - FAIXA), c.erro * f, dif.erro * (1 + FAIXA))
  c.desvio = ui.mid(dif.desvio * (1 - FAIXA), c.desvio / f, math.min(1, dif.desvio * (1 + FAIXA)))
end

-- Decide a cada `reacao` frames: mira no Y do jogador (+-erro), desvia de tiros, quer atirar se alinhada.
local function pensa_cpu(c)
  local alvo = players[1]
  c.cont = c.cont - 1
  if c.cont <= 0 then
    c.cont = math.max(1, math.floor(c.reacao + 0.5))
    local e = math.floor(c.erro + 0.5)
    c.alvo_y = alvo.y + math.random(-e, e)
    for i = 1, MAX_TIROS do
      local t = tiros[i]
      if t.ativo and t.dono == 1 and t.x < c.x and t.y + 5 > c.y - 4 and t.y < c.y + c.h + 4 then
        if math.random() < c.desvio then
          if t.y + 2 < c.y + c.h / 2 then c.alvo_y = t.y + 10 else c.alvo_y = t.y - c.h - 6 end
          if c.alvo_y < 24 then c.alvo_y = t.y + 10 elseif c.alvo_y > H - c.h then c.alvo_y = t.y - c.h - 6 end
        end
        break
      end
    end
    c.quer_atirar = math.abs(c.y - alvo.y) < ALINHADO
  end
  local dy, diff = 0, c.alvo_y - c.y
  if diff > 2 then dy = 1 elseif diff < -2 then dy = -1 end
  -- no "inverte" a CPU tambem fica confusa: anda errado nos primeiros CONFUSAO frames, depois compensa
  if fase == "ativo" and evento.inv and (evento.dur - timer) < CONFUSAO then dy = -dy end
  local atira = c.quer_atirar and math.abs(c.y - alvo.y) < ALINHADO
  return 0, dy, atira
end

local function atualiza_player(p)
  local dx, dy, atira = 0, 0, false
  if p.cpu then
    dx, dy, atira = pensa_cpu(p)
  else
    if ui.btn(LEFT, PAD1) then dx = dx - 1 end
    if ui.btn(RIGHT, PAD1) then dx = dx + 1 end
    if ui.btn(UP, PAD1) then dy = dy - 1 end
    if ui.btn(DOWN, PAD1) then dy = dy + 1 end
    if fase == "ativo" and evento.inv then dx, dy = -dx, -dy end
    atira = ui.btnp(ACAO, PAD1)
  end

  local v = VEL * mod("vel")
  p.x, p.y = p.x + dx * v, p.y + dy * v
  if p.id == 1 then p.x = ui.mid(0, p.x, MEIO - p.w - 4)
  else p.x = ui.mid(MEIO + 4, p.x, W - p.w) end
  p.y = ui.mid(24, p.y, H - p.h)

  if p.recarga > 0 then p.recarga = p.recarga - 1 end
  if p.hit > 0 then p.hit = p.hit - 1 end
  if atira and p.recarga <= 0 then
    atirar(p)
    p.recarga = math.floor(RECARGA * mod("rec"))
    p.quer_atirar = false
  end
end

local function atualiza_tiros()
  for i = 1, MAX_TIROS do
    local t = tiros[i]
    if t.ativo then
      t.x = t.x + t.dir * t.v
      if t.x < -8 or t.x > W + 8 then t.ativo = false end
      local alvo = players[t.dono == 1 and 2 or 1]
      if t.ativo and alvo.hit == 0 and t.x < alvo.x + alvo.w and t.x + 5 > alvo.x
         and t.y < alvo.y + alvo.h and t.y + 5 > alvo.y then
        t.ativo = false
        alvo.vidas, alvo.hit, shake = alvo.vidas - 1, 45, 12
        ajusta_ia(alvo.cpu)
        explode(alvo.x + 8, alvo.y + 8, alvo.cor, 12)
        if alvo.vidas <= 0 then
          explode(alvo.x + 8, alvo.y + 8, BRANCO, 25)
          vencedor, estado, shake = t.dono, "fim", 25
        end
      end
    end
  end
  for i = 1, MAX_PART do
    local p = parts[i]
    if p.vida > 0 then p.x, p.y, p.vida = p.x + p.vx, p.y + p.vy, p.vida - 1 end
  end
end

-- ================= DESENHO =================
local function desenha_fundo()
  ui.cls(T.fundo_cor)
  if T.fundo == "estrelas" then
    for i = 1, #estrelas do
      local s = estrelas[i]
      s.x = s.x - s.v * 0.5
      if s.x < 0 then s.x = W end
      ui.rectfill(s.x, s.y, s.x + 1, s.y + 1, s.v == 3 and BRANCO or CINZA)
    end
  elseif T.fundo == "chao" then
    for y = 40, H, 30 do ui.line(0, y, W, y, CINZA) end
  end
  for y = 24, H, 12 do ui.line(MEIO, y, MEIO, y + 5, CINZA) end
  -- FALHA NO SISTEMA: faixas de glitch quando um evento esta vindo/ativo (e de leve no titulo)
  if T.glitch and (fase ~= "normal" or estado == "titulo") and math.random() < (fase == "normal" and 0.15 or 0.5) then
    for i = 1, math.random(1, 4) do
      local gy = math.random(0, H - 4)
      local gx = math.random(-40, W - 40)
      ui.rectfill(gx, gy, gx + math.random(20, 160), gy + math.random(1, 3), math.random(0, 1) == 0 and VERDE or ROXO)
    end
  end
end

local function desenha_hud()
  local n1 = T.nome1
  ui.print(n1, 8, 6, T.cor1)
  for i = 1, players[1].vidas do ui.rectfill(12 + #n1 * 6 + i * 10, 6, 18 + #n1 * 6 + i * 10, 12, T.cor1) end
  local n2 = hud2
  ui.print(n2, W - 8 - #n2 * 6, 6, T.cor2)
  for i = 1, players[2].vidas do
    local x = W - 14 - #n2 * 6 - i * 10
    ui.rectfill(x, 6, x + 6, 12, T.cor2)
  end
end

local function desenha_evento()
  if fase == "aviso" then
    local c = prox_evento.cor
    if (frame // 6) % 2 == 0 then
      ui.rect(0, 0, W - 1, H - 1, c); ui.rect(2, 2, W - 3, H - 3, c)
      centro(T.aviso, 115, AMAR)
    end
    centro(nome_ev(prox_evento) .. " EM " .. (timer // 60 + 1), 135, c)
  elseif fase == "ativo" then
    local c = evento.cor
    for k = 0, 2 do ui.rect(k, k, W - 1 - k, H - 1 - k, c) end
    centro("<< " .. nome_ev(evento) .. " >>", 30, c)
    local larg = math.floor((timer / evento.dur) * 120)
    ui.rectfill(MEIO - 60, 18, MEIO - 60 + larg, 20, c)
  end
end

reset()

function update()
  frame = frame + 1
  ui.camera()
  desenha_fundo()

  if estado == "titulo" then
    centro(T.titulo, 90, AMAR)
    centro("VOCE vs " .. T.nome2, 106, T.cor2)
    centro("WASD/direcional move, K atira", 124, BRANCO)
    centro("fique atento aos avisos na tela!", 138, ROXO)
    if apertou(UP) then dif_idx = math.max(1, dif_idx - 1) end
    if apertou(DOWN) then dif_idx = math.min(#ORDEM_DIF, dif_idx + 1) end
    for i = 1, #ORDEM_DIF do
      local d = DIFICULDADES[ORDEM_DIF[i]]
      centro(i == dif_idx and ("> " .. d.nome .. " <") or d.nome, 158 + i * 12, i == dif_idx and AMAR or CINZA)
    end
    if (frame // 30) % 2 == 0 then centro("cima/baixo: dificuldade   K: comecar", 222, VERDE) end
    if apertou(ACAO) then reset(); estado = "jogo" end
    return
  end

  if estado == "jogo" then
    atualiza_eventos()
    atualiza_player(players[1])
    atualiza_player(players[2])
  end
  atualiza_tiros()

  if shake > 0 then
    ui.camera(math.random(-4, 4), math.random(-4, 4))
    shake = shake - 1
  end

  for _, p in ipairs(players) do
    if p.vidas > 0 and (p.hit == 0 or (frame // 3) % 2 == 0) then
      forma(T.forma, p.x, p.y, p.w, p.h, p.cor, p.dir)
    end
  end
  for i = 1, MAX_TIROS do
    local t = tiros[i]
    if t.ativo then forma(T.tiro_forma, t.x, t.y, 5, 5, t.dono == 1 and T.cor1 or T.cor2, t.dir) end
  end
  for i = 1, MAX_PART do
    local p = parts[i]
    if p.vida > 0 then ui.rectfill(p.x, p.y, p.x + 2, p.y + 2, p.cor) end
  end

  ui.camera()
  desenha_hud()
  if estado == "jogo" then desenha_evento() end

  if estado == "fim" then
    centro(vencedor == 1 and "VOCE VENCEU!" or "CPU VENCEU!", 115, vencedor == 1 and T.cor1 or T.cor2)
    if (frame // 30) % 2 == 0 then centro("K para revanche", 145, BRANCO) end
    if apertou(ACAO) then reset(); estado = "jogo" end
  end
end
