# ImagiVet

Jogo de navegador para estudar tomografia computadorizada (TC) veterinária.
Funciona no computador, no tablet e no celular: o layout se adapta à tela.

## Modos de jogo

- **Jogar agora**: partida de teste com os 10 casos clínicos. Mostra os pontos, mas não conta nada.
- **Níveis 1 a 5** (valem pontos): Fundamentos, Densidades e janelas, Aplicações clínicas,
  Técnica e artefatos, Casos e desafios. O nível vem do marcador `N|` em `tool/novas_questoes.txt`.
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
