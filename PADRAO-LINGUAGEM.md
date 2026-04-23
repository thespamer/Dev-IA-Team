# Padrao de Linguagem

Este projeto adota padrao de idioma por tipo de arquivo para reduzir ambiguidade.

## Regras

1. **Prompts de pods** (`agents/pods/*/PROMPT.md`): Portugues (PT-BR).
2. **Scripts e identificadores tecnicos**: Ingles tecnico (nomes de comandos, flags e termos de shell).
3. **Documentacao operacional principal**:
   - `README.md`: Ingles
   - `PASSO-A-PASSO.md`: Portugues
   - `CONTRIBUTING.md`: Portugues
4. **Nao misturar idiomas no mesmo bloco explicativo**, exceto termos tecnicos inevitaveis.

## Checklist rapido para PR

- O arquivo segue o idioma esperado para sua categoria?
- Novas secoes mantem consistencia com o idioma do arquivo?
- Exemplos de comando preservam nomes tecnicos originais?
