# Caixa-e-Água — instalador para Linux Mint 22.3

Este repositório preserva o projeto Caixa-e-Água da FURB e acrescenta um
instalador para Linux Mint 22.3, baseado no Ubuntu 24.04.

O instalador original de 2016 não funciona nessa distribuição: cita pacotes
removidos, depende de um comportamento antigo do GCC e continua executando
após falhas. O script novo baixa o pacote de lançamento original, valida sua
soma SHA-256, usa dependências atuais e para imediatamente em caso de erro.

## Instalação

No computador Linux, abra o terminal e execute:

```bash
git clone https://github.com/LeviRiibeiro/eaguanovo.git
cd eaguanovo
bash scripts/install-mint-22.sh
```

Se uma execução anterior desse instalador foi interrompida depois de extrair
`~/Caixa-e-Agua`, retome-a sem apagar seus arquivos com:

```bash
bash scripts/install-mint-22.sh --resume
```

O processo pede a senha de administrador para instalar as dependências e a
regra de acesso ao Kinect. Ele baixa cerca de 150 MB e pode demorar bastante
ao compilar Vrui, Kinect e SARndbox.

Ao terminar, execute:

```bash
~/.local/bin/Caixa-e-Agua
```

Também é possível abrir **Caixa-e-Água** pelo menu de aplicativos.
O instalador também cria o ícone **Caixa-e-Água** na Área de Trabalho.

## Observações

- O script é voltado para o Kinect de primeira geração usado pelo projeto.
- A instalação é feita em `~/Caixa-e-Agua`, `~/Vrui-3.1` e
  `~/.cache/eaguanovo`; não depende do pendrive nem do diretório a partir do
  qual o comando foi executado.
- Para não apagar configurações ou materiais existentes, a instalação é
  interrompida se `~/Caixa-e-Agua` já existir.
- O hardware (Kinect, projetor e calibração) ainda precisa ser validado no
  computador de destino.

## Origem

Projeto original: [lifefurb/caixaeagua](https://github.com/lifefurb/caixaeagua).
O software SARndbox e suas dependências são distribuídos sob GPL, conforme o
projeto original.
