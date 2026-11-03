# Chatwoot (fork uamartins)

## O que é

O Chatwoot oficial com o **WhatsApp nativo**, que fala com o conector
[`uamartins/whatsapp-connector`](https://github.com/uamartins/whatsapp-connector)
(fork MIT do conector da fazer.ai) por Redis Streams, no protocolo v1 do
conector.

O nativo inclui QR, mensagens, mídia, edição, exclusão, reação, recibos,
"digitando", histórico e grupos. Outros recursos de outros forks não entram por
padrão.

## Base e versões

- Branch de trabalho: `uam/main`, que nasceu da tag oficial `v4.19.1`.
- Versões: `vX.Y.Z-uam.N`, onde `X.Y.Z` é a versão oficial da base.
- Imagem: `ghcr.io/uamartins/chatwoot:<versão>`, publicada pelo
  `.github/workflows/uam-publish.yml` a cada tag `v*-uam.*`.

## Licença

- Tudo fora de `enterprise/` é MIT (Chatwoot Inc.), e o que vier da fazer.ai
  mantém o copyright da FAZER.AI LTDA, conforme o `LICENSE` original.
- `enterprise/` está sob a licença Enterprise da Chatwoot Inc.: a pasta fica
  no repositório só porque vem do oficial. **Ela não entra na imagem**
  (`.dockerignore`), e o `bin/uam-check-image` reprova a imagem que a tiver.
  **Nada de `enterprise/` é copiado ou usado como base** para código deste
  fork.

## Regras

- Toda edição em arquivo do oficial leva um comentário `uam:`. Para achar
  todas: `git grep -n "uam:"`.
- As extensões de classes do oficial ficam em `custom/` e entram pelo
  mecanismo do próprio Chatwoot (`prepend_mod_with` / `include_mod_with`).
- Os arquivos novos trazidos da fazer.ai mantêm o caminho original, para dar
  para comparar com o fork deles por `git diff`.
- A ligação no navegador é escrita sem `enterprise/`. O código de ligação da
  fazer.ai que fica fora de `enterprise/` é MIT e pode ser reaproveitado
  (decisão de 2026-11-02). Um log de fontes registra o que foi consultado.

## Origem do código

- Arquivos copiados da fazer.ai entram por `bin/uam-port <caminho>`, byte a
  byte, a partir da tag `v4.19.0-fazer-ai.141`. Cada um tem uma linha em
  `uam/ported.tsv` (caminho, tag, blob e as edições `uam:`, se houver).
- O `NOTICE` traz os avisos de copyright do Chatwoot Inc. e da FAZER.AI LTDA.
- As specs rodam sem `enterprise/`: `bin/uam-spec` no Docker local e o
  workflow `uam-spec.yml` no CI.

## Sincronização

- **Oficial:** um merge por mês, numa tag estável (`git fetch upstream
  --tags`, depois `git merge vX.Y.Z` em `uam/main`). Os conflitos aparecem só
  nas linhas `uam:`.
- **fazer.ai:** só correções da integração nativa, puxadas uma a uma.
