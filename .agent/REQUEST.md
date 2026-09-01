# Orchestrator Request

## Objective

Criar um kit reutilizável que coordene planejamento, implementação, validação e
revisão entre Claude Code e Codex em qualquer projeto.

## Requirements

- Instalar os arquivos de coordenação em um projeto-alvo.
- Não depender de linguagem, framework ou serviço externo.
- Preservar arquivos de instrução existentes por padrão.
- Informar a próxima ação a partir de um estado compartilhado.
- Fornecer templates para requisito, plano, tarefas e revisão.

## Definition of Done

- O bootstrap instala os templates em um diretório vazio.
- O comando de status indica corretamente a próxima IA responsável.
- O comportamento possui testes automatizados.
