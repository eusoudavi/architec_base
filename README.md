# Claude Skills

Skills pessoais para o Claude Code e o claude.ai.

| Skill | Para quê |
|---|---|
| `arquiteto-base` | Arquiteto Spring Boot com o padrão de classes base (BaseController, BaseService, BaseRepository, ServiceContract) |
| `solid` | SOLID, TDD e clean code ao escrever, revisar e planejar código |

## Claude Code (qualquer máquina)

```bash
git clone <url-deste-repo> ~/StudioProjects/claude-skills
~/StudioProjects/claude-skills/install.sh
```

O `install.sh` cria um link em `~/.claude/skills/<skill>` para cada pasta com `SKILL.md`.
Editar aqui = editar a skill instalada. Rode de novo depois de adicionar uma skill.
Não mexa em `~/.claude/skills/synced/`: é gerenciada pelo próprio Claude.

## claude.ai (navegador)

```bash
./build-zip.sh                 # gera dist/<skill>.zip de todas
./build-zip.sh arquiteto-base  # só uma
```

Faça upload do zip em **Settings → Capabilities → Skills**. Se a skill tiver
`.claudeai-description`, esse texto (≤ 200 caracteres) substitui a descrição no zip;
a versão local mantém a descrição longa, que dá mais gatilhos ao Claude Code.

## Nova skill

1. Crie `<nome>/SKILL.md` com frontmatter `name` e `description` (e `references/` se precisar).
2. `./install.sh`
3. Commit.
