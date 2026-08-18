# Migración data-science-lab: dev-team v1.0.0 → v1.4.0

## Contexto

Este documento es una instrucción completa para un agente Claude Code conectado al repositorio
`https://github.com/MarianodelRio/data-science-lab`. El objetivo es migrar el framework
dev-team embebido en ese repositorio desde v1.0.0 hasta v1.4.0.

**Repositorio fuente (dev-team v1.4.0):** `https://github.com/MarianodelRio/dev-team`
— rama `main`, que está actualmente en v1.4.0.

**Repositorio destino (tu repo):** `data-science-lab` — rama `main`.

---

## Estado actual del repositorio (inventario auditado)

Lo que ya está bien — NO tocar:
- `advisor.md` → ya tiene `model: claude-fable-5` ✓
- `devteam.config.yml` → tiene `review_profile: auto` ✓, solo faltan claves nuevas
- Project agents propios: `api-agent.md`, `frontend-agent.md`, `infra-agent.md`, `pipeline-agent.md` ✓
- Estructura de `tasks/` con todas las subcarpetas ✓
- Solo existe la rama `main` — no hay trabajo en progreso en ramas remotas

Lo que falta o está desactualizado:
- 9 agentes framework desactualizados
- 2 agentes nuevos que no existen
- 13 comandos desactualizados
- 2 comandos nuevos que no existen
- 7 scripts desactualizados
- 2 scripts nuevos que no existen
- Carpeta `.claude/steering/` no existe (4 ficheros nuevos)
- `.claude/AGENTS.md` no existe
- `context/` usa ficheros planos (v1.0) en vez de carpetas por tarea (v1.1+)
- `devteam.config.yml` en v1.0.0, faltan claves de v1.1–v1.4
- `spec.md` no existe (añadido en v1.1.0)

---

## Instrucciones de ejecución

Trabaja de forma secuencial en el orden indicado. Cada sección es un bloque atómico.
Usa sub-agentes en paralelo cuando se indique explícitamente.

---

## PASO 0 — Preparación: clonar dev-team como referencia

Clona el repositorio de dev-team en una carpeta temporal fuera de data-science-lab.
Usa sparse-checkout para traer solo lo que necesitas:

```bash
git clone --no-checkout --depth 1 https://github.com/MarianodelRio/dev-team /tmp/dev-team-ref
cd /tmp/dev-team-ref
git sparse-checkout init --cone
git sparse-checkout set .claude/agents .claude/commands .claude/steering scripts
git checkout main
```

Verifica que los ficheros están disponibles:
```bash
ls /tmp/dev-team-ref/.claude/agents/
ls /tmp/dev-team-ref/.claude/commands/
ls /tmp/dev-team-ref/.claude/steering/
ls /tmp/dev-team-ref/scripts/
```

A partir de aquí, `/tmp/dev-team-ref/` es tu fuente de verdad para todos los ficheros
del framework.

---

## PASO 1 — Actualizar agentes framework (reemplazar 9, añadir 2)

**IMPORTANTE:** No tocar `advisor.md` (ya está en v1.4) ni los project agents
(`api-agent.md`, `frontend-agent.md`, `infra-agent.md`, `pipeline-agent.md`).

### 1a. Reemplazar agentes existentes

Copia los siguientes ficheros desde dev-team-ref hacia data-science-lab, sobreescribiendo:

```bash
for agent in orchestrator architect planner coder code-quality security adversarial smoke-tester mutation-tester; do
  cp /tmp/dev-team-ref/.claude/agents/${agent}.md .claude/agents/${agent}.md
done
```

### 1b. Añadir agentes nuevos (no existen en el repo)

```bash
cp /tmp/dev-team-ref/.claude/agents/review-coordinator.md .claude/agents/review-coordinator.md
cp /tmp/dev-team-ref/.claude/agents/spec-coverage.md .claude/agents/spec-coverage.md
```

`review-coordinator` (nuevo en v1.2.0): orquesta la revisión paralela con perfiles
fast/full/auto. El orchestrator lo invoca en Phase 4 en lugar de lanzar los reviewers
directamente.

`spec-coverage` (nuevo en v1.3.0): mapea constraints de spec.md a tests del diff.
Advisory — nunca bloquea un PR.

### 1c. Verificar

```bash
ls .claude/agents/
# Debe haber: adversarial, advisor, api-agent, architect, code-quality, coder,
# frontend-agent, infra-agent, mutation-tester, orchestrator, pipeline-agent,
# planner, review-coordinator, security, smoke-tester, spec-coverage
```

---

## PASO 2 — Actualizar comandos (reemplazar 13, añadir 2)

### 2a. Reemplazar comandos existentes

```bash
for cmd in orchestrate done bootstrap bug explore add-task status prepare-pr cancel restart cheatsheet guide team-init; do
  cp /tmp/dev-team-ref/.claude/commands/${cmd}.md .claude/commands/${cmd}.md
done
```

Los cambios más significativos:
- `orchestrate.md`: Phase 0 completamente rehecho (extrae config como variables,
  carga steering files, carga memoria retrospectiva, valida cap de tareas paralelas)
- `done.md`: añade Step 3.5 para extracción de lecciones retrospectivas
- `bootstrap.md`: añade Mode 5 (brownfield) — necesario para generar spec.md

### 2b. Añadir comandos nuevos

```bash
cp /tmp/dev-team-ref/.claude/commands/refine.md .claude/commands/refine.md
cp /tmp/dev-team-ref/.claude/commands/reopen.md .claude/commands/reopen.md
```

`refine.md` (nuevo en v1.1.0): edición segura de spec.md con propagación por estado
de tarea. Nunca editar spec.md directamente — siempre via /refine.

`reopen.md` (nuevo en v1.2.0): mueve una tarea de pr-open/ de vuelta a available/
cuando un PR es rechazado o cerrado sin merge.

### 2c. Verificar

```bash
ls .claude/commands/
# Debe haber 15 ficheros .md
```

---

## PASO 3 — Actualizar y añadir scripts

### 3a. Reemplazar scripts existentes

```bash
for script in dt-common dt-claim dt-board dt-cancel dt-done dt-restart dt-ready; do
  cp /tmp/dev-team-ref/scripts/${script}.sh scripts/${script}.sh
done
chmod +x scripts/*.sh
```

### 3b. Añadir scripts nuevos (no existen en el repo)

```bash
cp /tmp/dev-team-ref/scripts/dt-pr.sh scripts/dt-pr.sh
cp /tmp/dev-team-ref/scripts/dt-verify.sh scripts/dt-verify.sh
chmod +x scripts/dt-pr.sh scripts/dt-verify.sh
```

`dt-pr.sh`: crea el PR en GitHub via `gh pr create` y mueve la tarea a `pr-open/`.
El orchestrator lo usa al final de Phase 4 (antes en v1.0 el orchestrator lanzaba
`gh pr create` directamente).

`dt-verify.sh`: ejecuta test + lint + type-check contra el worktree. El orchestrator
lo usa antes y después de review en Phase 4.

### 3c. Verificar

```bash
ls scripts/
# Debe haber: dt-board, dt-cancel, dt-claim, dt-common, dt-done, dt-pr, dt-ready,
# dt-restart, dt-verify
```

---

## PASO 4 — Crear steering files (nuevos en v1.3.0)

### 4a. Crear carpeta y copiar ficheros

```bash
mkdir -p .claude/steering
cp /tmp/dev-team-ref/.claude/steering/always.md .claude/steering/always.md
cp /tmp/dev-team-ref/.claude/steering/task-format.md .claude/steering/task-format.md
cp /tmp/dev-team-ref/.claude/steering/context-formats.md .claude/steering/context-formats.md
cp /tmp/dev-team-ref/.claude/steering/coder-complete.md .claude/steering/coder-complete.md
```

Estos ficheros reemplazan el sistema de `AGENTS.md` monolítico. El orchestrator los
lee en Phase 0 y los inyecta inline en el prompt de cada sub-agente según su scope:
- `always.md` → todos los agentes
- `task-format.md` → todos los agentes
- `context-formats.md` → orchestrator, architect, coder, planner
- `coder-complete.md` → solo el coder

### 4b. Añadir AGENTS.md stub

```bash
cp /tmp/dev-team-ref/.claude/AGENTS.md .claude/AGENTS.md
```

Es un stub de ~10 líneas que apunta a steering/ — reemplaza el AGENTS.md monolítico
de v1.2.0 (si existe) o es nuevo si no había ninguno.

### 4c. Verificar

```bash
ls .claude/steering/
ls .claude/AGENTS.md
```

---

## PASO 5 — Migrar estructura de context/

Este es el paso más delicado. En v1.0.0 el contexto se guardaba en dos ficheros planos.
En v1.1.0+ pasó a ser un fichero por tarea en subcarpetas.

### Estado actual

```
context/decisions.md    ← 147KB, entradas por tarea
context/discoveries.md  ← 79KB, alertas cross-agente
```

### Estructura de decisions.md

Las entradas están organizadas con este patrón de cabecera:

```
## YYYY-MM-DD — T-XXX [Nombre del agente]
Decided: ...
Why: ...
Affects: ...
Discarded: ...
```

### Migración de decisions.md → context/decisions/

```bash
mkdir -p context/decisions
```

Divide `context/decisions.md` en ficheros individuales por tarea. El patrón de
división es cada cabecera `## YYYY-MM-DD — T-XXX` o `## YYYY-MM-DD — B-XXX`.

Estrategia recomendada: usa un script Python para dividir el fichero:

```bash
python3 - <<'EOF'
import re
import os

with open('context/decisions.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Split on task headers
pattern = r'(?=^## \d{4}-\d{2}-\d{2} — [TB]-\d+)'
sections = re.split(pattern, content, flags=re.MULTILINE)

# Extract preamble (before first task entry)
preamble = sections[0].strip()
task_sections = sections[1:]

os.makedirs('context/decisions', exist_ok=True)

if preamble:
    with open('context/decisions/legacy-header.md', 'w', encoding='utf-8') as f:
        f.write(preamble + '\n')

task_map = {}
for section in task_sections:
    match = re.match(r'^## \d{4}-\d{2}-\d{2} — ([TB]-\d+)', section.strip())
    if match:
        task_id = match.group(1)
        if task_id not in task_map:
            task_map[task_id] = []
        task_map[task_id].append(section.strip())

for task_id, entries in task_map.items():
    filename = f'context/decisions/{task_id}.md'
    with open(filename, 'w', encoding='utf-8') as f:
        f.write('\n\n---\n\n'.join(entries) + '\n')
    print(f'Created {filename} ({len(entries)} entries)')

print(f'\nTotal task files created: {len(task_map)}')
EOF
```

Verifica que los ficheros se crearon correctamente:
```bash
ls context/decisions/ | head -20
```

### Migración de discoveries.md → context/discoveries/

Las discoveries son alertas cross-agente, no son propiedad de una sola tarea.
La estrategia más segura es conservarlas en un fichero de legado y empezar
los nuevos en formato por-tarea:

```bash
mkdir -p context/discoveries
cp context/discoveries.md context/discoveries/legacy.md
touch context/discoveries/.gitkeep
```

El fichero `legacy.md` preserva todo el historial. Las nuevas discoveries de tareas
futuras se crearán como `context/discoveries/T-XXX.md` directamente.

### Crear carpeta de retrospectivas (nueva en v1.3.0)

```bash
mkdir -p context/retrospectives
touch context/retrospectives/.gitkeep
```

### Limpiar ficheros planos originales

Una vez verificado que los datos están en las nuevas carpetas:

```bash
rm context/decisions.md
rm context/discoveries.md
```

### Verificar estructura final de context/

```bash
find context/ -type f | sort
# Debe incluir:
# context/decisions/T-001.md ... T-031.md (y B-001.md)
# context/discoveries/legacy.md
# context/discoveries/.gitkeep
# context/retrospectives/.gitkeep
```

---

## PASO 6 — Actualizar devteam.config.yml

El fichero actual está en v1.0.0. Hay que añadir las claves nuevas **sin sobreescribir
los valores existentes**. Edita `devteam.config.yml` y aplica los siguientes cambios:

### 6a. Cambiar la versión en la primera línea

```yaml
devteam_version: "1.4.0"     # cambiar de "1.0.0"
```

### 6b. Añadir max_parallel_tasks en la sección orchestration

La sección orchestration actual no tiene `max_parallel_tasks`. Añádela:

```yaml
orchestration:
  max_parallel_tasks: 5           # AÑADIR esta línea
  timeout_s: 120
  timeout_m: 240
  timeout_l: 480
  max_rebase_auto_retries: 2
  max_blocker_retries: 2
```

### 6c. Añadir claves de spec coverage en la sección quality

La sección quality tiene `review_profile: auto` ya. Añadir al final de la sección:

```yaml
quality:
  # ... (mantener todo lo existente) ...
  spec_coverage_enabled: false    # AÑADIR: mapeo spec.md → tests (advisory). Activar tras generar spec.md
  spec_coverage_threshold: 80     # AÑADIR: % mínimo de constraints cubiertos antes de WARN_LOW
```

### 6d. Añadir sección memory (no existe)

Añadir al final del fichero, antes del cierre:

```yaml
# ─────────────────────────────────────────
# MEMORY
# ─────────────────────────────────────────
memory:
  retrospective_memory_enabled: true  # Lecciones extraídas en /done, inyectadas en /orchestrate Phase 0
```

### 6e. Verificar que el YAML es válido

```bash
python3 -c "import yaml; yaml.safe_load(open('devteam.config.yml'))" && echo "YAML válido"
```

---

## PASO 7 — Commit de todos los cambios mecánicos

En este punto todos los cambios de ficheros framework están listos. Haz un commit
antes de continuar con la generación de spec.md:

```bash
git add .claude/agents/ .claude/commands/ .claude/steering/ .claude/AGENTS.md
git add scripts/
git add context/decisions/ context/discoveries/ context/retrospectives/
git add devteam.config.yml
git status  # revisar que solo están los ficheros esperados
git commit -m "chore: migrate dev-team framework v1.0.0 → v1.4.0

- Update 9 framework agents to v1.4 versions
- Add review-coordinator and spec-coverage agents
- Update 13 commands; add /refine and /reopen
- Update 7 scripts; add dt-pr.sh and dt-verify.sh
- Add .claude/steering/ (4 scoped rule files + AGENTS.md stub)
- Migrate context/ from flat files to per-task folder structure
- Add context/retrospectives/ for v1.3 memory system
- Update devteam.config.yml to v1.4.0 with new config keys"

git push origin main
```

---

## PASO 8 — Generar spec.md (el paso más importante)

`spec.md` es el artefacto que faltaba desde v1.1.0. Contiene por módulo: qué hace,
lógica de negocio, interfaz (inputs/outputs/errores) y qué está fuera de alcance.

Con 32 tareas completadas hay suficiente código implementado para generarlo.

### Ejecutar /bootstrap en modo brownfield

Ejecuta el comando `/bootstrap` y cuando pregunte el modo, selecciona **Mode 5
(brownfield)**. El agente de bootstrap:

1. Escanea el codebase existente (`src/`, `tests/`, `frontend/`, etc.)
2. Lee `design.md` y `plan.md` para entender la arquitectura prevista
3. Lee las tareas en `tasks/done/` para entender qué se ha implementado
4. Genera `spec.md` describiendo los módulos reales tal como existen
5. Identifica si hay tareas available/blocked que necesiten ajuste por gaps

**NO generará código nuevo ni modificará tareas existentes.**

### Qué debe quedar en spec.md

Una sección por módulo con:
```markdown
## [Nombre del módulo]

**What it does** — 1-2 frases

**Logic** — reglas de negocio no obvias, edge cases, modos de fallo

**Interface** — inputs (fuente + formato), outputs (destino + formato), errores

**Out of scope** — qué no hace este módulo deliberadamente
```

Y una sección de flujos cross-módulo que trace cada flujo significativo paso a paso.

### Verificar

```bash
ls -la spec.md
wc -l spec.md  # debe ser >100 líneas para un proyecto de esta escala
```

---

## PASO 9 — Activar spec-coverage (opcional, después de verificar spec.md)

Una vez que tengas spec.md y lo hayas revisado, puedes activar el agente
spec-coverage en reviews. Edita `devteam.config.yml`:

```yaml
spec_coverage_enabled: true   # cambiar de false a true
```

Esto hará que el review-coordinator incluya spec-coverage en cada Phase 4.
Es advisory — nunca bloquea un PR.

---

## PASO 10 — Verificación final

```bash
# Estructura completa
find .claude/ -type f | sort
find context/ -type f | sort
find scripts/ -name "*.sh" | sort

# Agentes
echo "Agentes:" && ls .claude/agents/ | wc -l  # debe ser 16

# Comandos
echo "Comandos:" && ls .claude/commands/ | wc -l  # debe ser 15

# Scripts
echo "Scripts:" && ls scripts/*.sh | wc -l  # debe ser 9

# Steering
echo "Steering:" && ls .claude/steering/ | wc -l  # debe ser 4

# spec.md
ls spec.md && echo "spec.md OK"

# Config
python3 -c "
import yaml
cfg = yaml.safe_load(open('devteam.config.yml'))
assert cfg.get('devteam_version') == '1.4.0', 'version incorrecta'
assert 'spec_coverage_enabled' in cfg.get('quality', {}), 'falta spec_coverage_enabled'
assert 'retrospective_memory_enabled' in cfg.get('memory', {}), 'falta memory section'
print('devteam.config.yml OK')
"
```

Si todo pasa: la migración está completa. Ejecuta `/team-init` para confirmar el
estado del proyecto y que el framework reconoce la nueva versión.

---

## Resumen de cambios por fichero

| Fichero | Acción |
|---|---|
| `.claude/agents/orchestrator.md` | Reemplazar |
| `.claude/agents/architect.md` | Reemplazar |
| `.claude/agents/planner.md` | Reemplazar |
| `.claude/agents/coder.md` | Reemplazar |
| `.claude/agents/code-quality.md` | Reemplazar |
| `.claude/agents/security.md` | Reemplazar |
| `.claude/agents/adversarial.md` | Reemplazar |
| `.claude/agents/smoke-tester.md` | Reemplazar |
| `.claude/agents/mutation-tester.md` | Reemplazar |
| `.claude/agents/review-coordinator.md` | **Añadir nuevo** |
| `.claude/agents/spec-coverage.md` | **Añadir nuevo** |
| `.claude/agents/advisor.md` | NO tocar (ya en v1.4) |
| `.claude/agents/api-agent.md` | NO tocar (project agent) |
| `.claude/agents/frontend-agent.md` | NO tocar (project agent) |
| `.claude/agents/infra-agent.md` | NO tocar (project agent) |
| `.claude/agents/pipeline-agent.md` | NO tocar (project agent) |
| `.claude/commands/orchestrate.md` | Reemplazar |
| `.claude/commands/done.md` | Reemplazar |
| `.claude/commands/bootstrap.md` | Reemplazar |
| `.claude/commands/bug.md` | Reemplazar |
| `.claude/commands/explore.md` | Reemplazar |
| `.claude/commands/add-task.md` | Reemplazar |
| `.claude/commands/status.md` | Reemplazar |
| `.claude/commands/prepare-pr.md` | Reemplazar |
| `.claude/commands/cancel.md` | Reemplazar |
| `.claude/commands/restart.md` | Reemplazar |
| `.claude/commands/cheatsheet.md` | Reemplazar |
| `.claude/commands/guide.md` | Reemplazar |
| `.claude/commands/team-init.md` | Reemplazar |
| `.claude/commands/refine.md` | **Añadir nuevo** |
| `.claude/commands/reopen.md` | **Añadir nuevo** |
| `scripts/dt-common.sh` | Reemplazar |
| `scripts/dt-claim.sh` | Reemplazar |
| `scripts/dt-board.sh` | Reemplazar |
| `scripts/dt-cancel.sh` | Reemplazar |
| `scripts/dt-done.sh` | Reemplazar |
| `scripts/dt-restart.sh` | Reemplazar |
| `scripts/dt-ready.sh` | Reemplazar |
| `scripts/dt-pr.sh` | **Añadir nuevo** |
| `scripts/dt-verify.sh` | **Añadir nuevo** |
| `.claude/steering/always.md` | **Añadir nuevo** |
| `.claude/steering/task-format.md` | **Añadir nuevo** |
| `.claude/steering/context-formats.md` | **Añadir nuevo** |
| `.claude/steering/coder-complete.md` | **Añadir nuevo** |
| `.claude/AGENTS.md` | **Añadir nuevo** |
| `context/decisions/` | Crear y migrar desde decisions.md |
| `context/discoveries/` | Crear con legacy.md |
| `context/retrospectives/` | **Crear nueva** |
| `devteam.config.yml` | Actualizar versión + añadir claves |
| `spec.md` | **Generar via /bootstrap brownfield** |
