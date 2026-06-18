# Rabbit PDV (Flutter Desktop)

Frente de caixa do Rabbit ERP. Offline-first, desktop-first (Linux/Windows), pensado para
canvas lógico 1280×800 com hit-targets mínimos de 44px.

## Como rodar

```bash
# 1. Instalar dependências
flutter pub get

# 2. Rodar em Linux desktop
flutter run -d linux

# Ou em Windows
flutter run -d windows
```

> **Fontes:** o app referencia `Inter` e `JetBrainsMono` mas elas **não estão
> empacotadas** no ZIP (para reduzir tamanho). O Flutter cai automaticamente
> para a fonte de sistema mais próxima — visualmente fica muito próximo. Para
> produção, baixe os `.ttf` em <https://fonts.google.com> e adicione na seção
> `fonts:` do `pubspec.yaml` (já há um bloco comentado pronto).

## O que está implementado

- ✅ Layout completo (topbar, abas de atendimento, scanner, painel de itens, painel lateral)
- ✅ Múltiplos atendimentos simultâneos (abrir, alternar, pausar, fechar)
- ✅ Scanner com flash verde/vermelho e busca textual debounced
- ✅ Carrinho com stepper de quantidade (1un / 0,1kg)
- ✅ Modo Atalhos com grade de produtos por categoria e badge "no carrinho"
- ✅ Tema claro/escuro persistido
- ✅ Atalhos globais: F1 (foco scanner), F5 (finalizar), F9 (pausar), Ctrl+N (novo)
- ✅ Catálogo mockado com 15 produtos em 5 categorias

## O que ainda não está

- ❌ Modal de pagamento (próximo passo natural)
- ❌ Modal de desconto, cliente, devolução, histórico
- ❌ Persistência local (Drift/SQLite) — repositório atualmente é in-memory
- ❌ Integração real com backend (Dio configurado mas sem chamadas)
- ❌ Outbox de sincronização
- ❌ Integração com hardware real (scanner USB-HID, balança serial, impressora)

## Estrutura

```
lib/
├── app/                       # Módulo raiz + AppWidget
├── core/
│   ├── theme/                 # AppColors (ThemeExtension), AppText, AppSpacing, buildTheme
│   ├── result/                # Result<T,E> sealed (Ok/Err)
│   ├── failures/              # Failure hierarchy (NotFound, Validation, Network…)
│   ├── format/                # BrlFormatter, UnidadeFormatter, TimeFormatter
│   └── widgets/               # AppButton, AppBrand, AppPill, AppKbd, StatusDot
├── domain/
│   ├── entities/              # Atendimento, ItemAtendimento, Cliente, Produto (imutáveis)
│   ├── enums/                 # AtendimentoStatus, UnidadeMedida, ClienteTipo, MetodoPagamento
│   └── repositories/          # Interfaces (ProdutosRepository)
├── data/
│   └── repositories/          # Mock in-memory (substituir por Drift+Dio)
└── features/
    └── pdv/
        ├── pdv_module.dart    # DI da feature
        └── presentation/
            ├── controllers/   # SessionsController, ViewController, ScannerController…
            ├── widgets/       # Topbar, TabsBar, Scanner, ItemsPanel, SidePanel…
            └── pages/         # PdvPage
```

## Padrões adotados

- **State management:** `ChangeNotifier` para controllers ricos + `ValueNotifier`
  para estados atômicos. Sem Provider/Riverpod/Bloc — `ListenableBuilder` direto.
- **Erros:** `Result<T, Failure>` sealed (sem exceptions na camada de domínio).
- **Imutabilidade:** entidades de domínio usam `Equatable` + `copyWith`. Mutações
  produzem novas instâncias.
- **DI:** `flutter_modular` — controllers não dependem dele direto (recebem deps
  no construtor, são apenas registrados no módulo).
- **Convenções de idioma:** PT-BR para conceitos de domínio (`Atendimento`,
  `Cliente`); inglês para conceitos genéricos (`Controller`, `Repository`).

## Atalhos

| Tecla    | Ação                              |
| -------- | --------------------------------- |
| F1       | Foco no scanner                   |
| F2       | Cliente (TODO)                    |
| F5       | Finalizar atendimento             |
| F6       | Desconto (TODO)                   |
| F9       | Pausar atendimento ativo          |
| Ctrl+N   | Novo atendimento                  |
| ↑/↓      | Navegar resultados no dropdown    |
| Enter    | Confirma item no scanner          |
| Esc      | Fecha dropdown de busca           |

## Testando o fluxo

1. Clique no campo do scanner (já vem com foco).
2. Digite um EAN de teste, ex.: `7891000100103` (Pão Francês) e Enter — flash verde, item adicionado.
3. Digite `xpto` e Enter — flash vermelho + toast "Produto não cadastrado".
4. Alterne para a aba "Atalhos" e clique em um produto.
5. `Ctrl+N` abre uma nova aba; pulse animado no dot acompanha a aba ativa.

---

Implementação base feita com Claude. Próximo passo recomendado: modal de pagamento.
