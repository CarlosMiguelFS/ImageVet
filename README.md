# ImagiVet

Jogo de navegador para estudar tomografia computadorizada (TC) veterinária.
Funciona no computador, no tablet e no celular: o layout se adapta à tela.

## Modos de jogo

- **Modo teste**: 10 casos clínicos para conhecer o jogo. Mostra os pontos, mas não conta nada.
- **Partida valendo** (botão "Jogar agora"): 10 questões sorteadas entre as 60 que valem pontos.
- **Sobrevivência**: as 60 questões que valem pontos, até acabarem as 3 vidas.

Para adicionar perguntas: edite `tool/novas_questoes.txt`, rode `dart run tool/gerar_questoes.dart`
e copie as linhas do gabarito mostradas para `supabase/schema.sql` (e rode o SQL no Supabase).

Pontos, combo, moedas, XP, estrelas, baú diário, ofensiva, conquistas e ranking.

## Como funciona

- Feito em Flutter Web; o site compilado fica em `build/web` e é publicado pela Vercel.
- Login, perfil e ranking usam o Supabase (projeto exclusivo do ImagiVet).
  O banco é criado rodando `supabase/schema.sql` no SQL Editor do projeto.
- A pontuação é calculada e validada no servidor: o navegador só informa a alternativa escolhida.
- Sem conta, dá para jogar com o progresso salvo só no navegador.

## Desenvolvimento

```sh
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Depois de compilar, faça commit da pasta `build/web` para a Vercel publicar a nova versão.
