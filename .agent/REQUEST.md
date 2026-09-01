# Feature Request

## Objective

Adicionar rate limiting por tenant.

## Requirements

- Cada tenant deve ter seu próprio limite.
- Limite configurável.
- Middleware deve rejeitar requests excedentes.
- Retornar HTTP 429.
- Deve existir teste unitário.

## Constraints

- Não adicionar Redis.
- Usar cache em memória.
- Não alterar contratos públicos existentes.

## Definition of Done

- Código compila.
- Testes passam.
- Linter passa.
- Feature possui testes.