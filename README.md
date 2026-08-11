# DreamServer IPTV App

App IPTV Flutter com visual estilo Netflix.
Funciona em celular Android e TV box.

## Como compilar

O APK é gerado automaticamente pelo GitHub Actions a cada push na branch `main`.

Acesse a aba **Actions** → clique no build mais recente → baixe o artifact **DreamServer-APK**.

## Configuração

A URL do servidor está hardcodada em:
`lib/services/xtream_service.dart` → constante `baseUrl`
