# Política de Uso

## Termos Gerais

Este serviço é oferecido "como está" (*as is*), sem garantias de qualquer tipo, expressas ou implícitas.

## Fonte dos Dados

Todos os dados pertencem ao **Sistema Nacional de Informações de Segurança Pública (SINESP)**, mantido pela **Secretaria Nacional de Segurança Pública (SENASP)** do **Ministério da Justiça e Segurança Pública**.

Este serviço apenas **facilita o acesso** e **não é afiliado ao governo brasileiro**.

## Limites de Uso

### Rate Limit
- **60 requisições por minuto** por IP (configurável)
- Respostas que excedem o limite recebem HTTP `429 Too Many Requests`

### Paginação
- Máximo de **1.000 registros por página**
- Padrão: 100 registros por página

### Previsão
- Horizonte máximo: **60 períodos** à frente
- Nível de confiança: 50% a 99%

## Frequência de Atualização

- Os dados são atualizados **semanalmente** (toda segunda-feira)
- O campo `last_refresh` no endpoint `/status` indica a data da última atualização
- Pode haver defasagem entre a publicação pelo SINESP e a disponibilização neste serviço

## Isenção de Responsabilidade

- Os dados são fornecidos para **fins de pesquisa empírica** exclusivamente
- Este serviço **não garante** a completude, precisão ou atualidade dos dados
- **Não use** estes dados como única fonte para tomada de decisão
- O serviço pode estar **indisponível** temporariamente para manutenção
- **Não nos responsabilizamos** por interpretações incorretas dos dados

## Uso Aceitável

**Permitido:**
- Pesquisa acadêmica e científica
- Jornalismo de dados (com citação da fonte)
- Análises de políticas públicas
- Projetos educacionais
- Desenvolvimento de aplicações que citem a fonte

**Não recomendado:**
- Criação de "scores de risco" para áreas ou indivíduos
- Discriminação territorial ou social
- Uso comercial sem atribuição da fonte
- Redistribuição sem atribuição adequada

## Atribuição

Ao usar dados deste serviço, cite:

> Dados: SINESP/SENASP — Ministério da Justiça e Segurança Pública.
> Disponibilizados via SINESP-as-a-Service (pacote BrazilCrime, CRAN).

## Contato

Para reportar problemas, abra uma issue no repositório do projeto.
