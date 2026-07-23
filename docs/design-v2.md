# dev-team v2 — Diseño de solución: Orchestrator como coordinador de subagentes

**Fecha:** 2026-07-23  
**Estado:** Diseño aprobado, pendiente de implementación  
**Autor:** Sesión de diseño con Mariano del Rio

---

## La mejora: de agente monolítico a coordinador especializado

### El problema con v1

En dev-team v1, el orchestrator es un agente monolítico que hace todo él mismo: elige la tarea, la analiza, la planea, escribe el código, corre los tests, verifica la calidad y marca el resultado. El único uso de subagentes ocurre en `/prepare-pr`, donde el `pr-reviewer` lanza los revisores especializados — pero ese comando lo corre el usuario manualmente como paso separado.

Esto crea varios problemas:
- El orchestrator tiene demasiada responsabilidad y contexto mixto (contexto de planificación + contexto de código + contexto de review en la misma sesión)
- Los revisores especializados (security, adversarial, smoke-tester, etc.) están desconectados del flujo de implementación — el usuario tiene que recordar correr `/prepare-pr`
- No hay separación entre razonamiento arquitectónico, implementación de código y revisión de calidad
- El usuario tiene que estar pendiente de correr `/prepare-pr` y `/done` como pasos manuales separados

### La solución v2

El orchestrator se convierte en un **coordinador puro** que delega trabajo especializado a subagentes. El usuario abre un chat, corre `/orchestrate`, y el sistema lleva la tarea de punta a punta — desde la validación inicial hasta la apertura del PR — con un único punto de aprobación humana.

```
ANTES (v1):
  Usuario → /orchestrate → orchestrator hace TODO → para
  Usuario → /prepare-pr → pr-reviewer lanza revisores → PR abre → para
  Usuario → /done → cierra

DESPUÉS (v2):
  Usuario → /orchestrate → orchestrator coordina:
              1. Architect analiza tarea
              [checkpoint humano]
              2. Planner crea plan
              3. Coder implementa
              4. Reviewers en paralelo
              → PR abierto → para
  Usuario → /done → cierra
```

Los workflows de `/bug` y `/explore` también se redefinen con roles claros:
- `/bug` = investigación + creación de tarea. La implementación la hace `/orchestrate` como cualquier tarea.
- `/explore` = investigación pura con architect + advisor. Sin código.

---

## Inventario de cambios

### Crear (nuevo)
```
.claude/agents/planner.md          Nuevo agente especializado en planificación
.claude/agents/coder.md            Nuevo agente especializado en implementación
docs/adr/0002-orchestrator-subagent-pattern.md   ADR de la decisión arquitectónica
```

### Reescribir completo
```
.claude/agents/orchestrator.md     Monolítico → coordinador de 4 fases
.claude/commands/orchestrate.md    Refleja las 4 fases + manejo de conflictos
.claude/commands/bug.md            Solo investigación + creación de tarea
.claude/commands/explore.md        Investigación con architect + advisor
```

### Actualizar
```
CLAUDE.md                          Lista de agentes, tabla de comandos, descripción de flujo
README.md                          Workflow, arquitectura de agentes, tabla de comandos
devteam.config.yml                 Nueva sección orchestration
CONTRIBUTING.md                    Lista de agentes actualizada
```

### Simplificar
```
.claude/commands/prepare-pr.md     Convertir en escape hatch manual únicamente
```

### Eliminar
```
.claude/agents/pr-reviewer.md      Su rol pasa directamente al orchestrator
```

### Sin cambios (15 archivos)
```
.claude/agents/architect.md
.claude/agents/advisor.md
.claude/agents/code-quality.md
.claude/agents/security.md
.claude/agents/adversarial.md
.claude/agents/smoke-tester.md
.claude/agents/mutation-tester.md
.claude/commands/done.md
.claude/commands/add-task.md
.claude/commands/restart.md
.claude/commands/cancel.md
.claude/commands/status.md
.claude/commands/guide.md
.claude/commands/team-init.md
.claude/commands/bootstrap.md
install.sh
```

---

## Especificaciones detalladas por archivo

---

### NUEVO: `.claude/agents/planner.md`

**Propósito:** Agente especializado en convertir una tarea aprobada en un plan concreto y accionable de implementación. No escribe código — produce el mapa que el Coder va a seguir.

**Frontmatter:**
```yaml
model: claude-sonnet-4-6
```

**Contenido que debe tener:**

- **Mission:** Producir un plan concreto de implementación a partir de una tarea aprobada. El plan debe ser lo suficientemente específico como para que el Coder pueda trabajar sin ambigüedades.

- **When to invoke:** Invocado por el Orchestrator en Fase 2, después del checkpoint humano y antes de la implementación.

- **Input que recibe (via prompt del Orchestrator):**
  - El task file completo (con cualquier ajuste aceptado en el checkpoint)
  - El path a `design.md`
  - El contenido relevante de `context/decisions.md` (entradas relacionadas con los módulos del task)
  - El contenido de `context/discoveries.md` (entradas OPEN que afectan al agente de esta tarea)

- **Lo que debe leer:** design.md (secciones de arquitectura relevantes al módulo del task), los archivos actuales en las carpetas asignadas al task (para entender el estado real del código antes de planear).

- **Lo que produce:**
  ```
  ## Plan — T-XXX

  ### Archivos a crear
  - path/al/archivo.py — [qué contiene, funciones principales]
  - path/al/test_archivo.py — [qué testea]

  ### Archivos a modificar
  - path/existente.py — [qué cambios: añadir función X, modificar función Y]

  ### Orden de implementación
  1. [primero esto — por qué]
  2. [luego esto]
  3. [finalmente esto]

  ### Decisiones de diseño
  - [decisión tomada y por qué — referencia a design.md si aplica]

  ### Tests requeridos
  - [tipo de test] para [función/módulo] — [qué escenario cubre]
  - (tipos según la Testing strategy en design.md para este módulo)

  ### Dependencias internas
  - [si el plan requiere que exista X antes de Y]

  ### Dudas sin resolver
  - [si hay alguna — o "Ninguna"]
  ```

- **Puede invocar:** Advisor (si hay un trade-off de diseño genuino al planear — p.ej. dos formas de estructurar el módulo con consecuencias distintas).

- **Formato de consulta al Advisor:**
  ```
  Context: [módulos involucrados, contratos existentes, constraints de design.md]
  Question: [la decisión específica de diseño]
  Output: opciones + trade-offs + recomendación concreta
  ```

- **Reglas:**
  - Nunca escribe código de producción — solo el plan
  - Nunca propone tocar archivos fuera de los `folders:` del task
  - Si detecta que el plan requeriría tocar contratos compartidos, lo señala explícitamente (no lo hace — lo señala al Orchestrator)
  - El plan debe ser específico a nivel de archivo y función, no vago ("implementar la lógica de X")
  - Si `context/discoveries.md` tiene entradas OPEN que afectan a este módulo, el plan debe incorporarlas o señalar por qué no aplican

---

### NUEVO: `.claude/agents/coder.md`

**Propósito:** Agente especializado en implementación. Recibe un plan y lo ejecuta en el worktree asignado. Escribe código, tests, y verifica calidad. No diseña — ejecuta el plan del Planner.

**Frontmatter:**
```yaml
model: claude-sonnet-4-6
```

**Contenido que debe tener:**

- **Mission:** Implementar el plan recibido con precisión dentro del worktree asignado. Código correcto, tests que pasen, calidad verificada.

- **When to invoke:** Invocado por el Orchestrator en Fase 3, después de recibir el plan del Planner.

- **Input que recibe (via prompt del Orchestrator):**
  - El plan completo del Planner
  - El path absoluto del worktree (`../project-T-XXX/`)
  - El task file completo (para leer `folders:` permitidos y los criterios de "Done when")
  - El path a `design.md` (para seguir patrones)

- **Todo el trabajo ocurre en el worktree.** El Coder nunca modifica archivos en el repo principal.

- **Protocolo de implementación:**
  1. Leer el plan del Planner completo antes de escribir una línea
  2. Seguir el orden de implementación del plan
  3. Escribir tests a medida que implementa (no después) — siguiendo los tipos de test del Testing strategy en design.md para este módulo
  4. Para fixtures y test doubles: usar la ubicación definida en el Testing strategy (`tests/fixtures/`), nunca hacer llamadas de red reales en unit tests
  5. Antes de escribir a `context/decisions.md` o `context/discoveries.md`: `git pull origin main --ff-only` desde el worktree (append-only, evitar conflictos)
  6. Escribir en `context/decisions.md` si toma una decisión no obvia
  7. Escribir en `context/discoveries.md` si descubre algo que afecta a otro módulo — NO tocar ese módulo

- **Verificación (debe pasar todo antes de reportar listo):**
  ```bash
  # Desde el worktree
  [test command de devteam.config.yml]      # Tests + coverage
  [lint command de devteam.config.yml]      # Lint + format
  [type_check command de devteam.config.yml] # Type checking
  ```

- **Commit:**
  ```bash
  git add [archivos específicos — nunca git add -A]
  git commit -m "T-XXX: [descripción corta de lo implementado]"
  git push origin feature/T-XXX-short-slug
  ```

- **Puede invocar:** Advisor si durante la implementación surge una decisión técnica con trade-offs reales (p.ej. dos librerías con consecuencias distintas, o un patrón de error handling no cubierto por el plan).

- **Si bloqueador real:** Para y devuelve un resultado estructurado al Orchestrator:
  ```
  BLOCKER — T-XXX
  Tipo: [decisión de diseño / ambigüedad en el plan / conflicto de contratos]
  Situación: [descripción precisa]
  Opciones: [A) ... B) ...]
  Recomendación: [la que prefiere el Coder, con justificación]
  Archivos afectados: [cuáles]
  ```

- **Reglas:**
  - Nunca escribe fuera de los `folders:` del task — si ve una mejora en otro módulo, la anota en `context/discoveries.md`
  - Nunca modifica contratos compartidos sin aprobación explícita del Orchestrator
  - Nunca usa `git add -A` o `git add .` — solo archivos específicos
  - Nunca hace commits en main — solo en la feature branch del worktree
  - Nunca salta la verificación — todo debe pasar antes de reportar listo
  - Si un test falla y el fix está en el plan: lo arregla. Si requiere decisión de diseño: bloqueador.

---

### REESCRIBIR: `.claude/agents/orchestrator.md`

**Cambio:** De "agente que implementa todo" a "coordinador de fases que delega y escala".

**Frontmatter:**
```yaml
model: claude-opus-4-8
```
(Usa el modelo reasoning — el Orchestrator toma decisiones, no escribe código.)

**Contenido que debe tener:**

- **Mission:** Coordinar la ejecución completa de una tarea — desde la validación inicial hasta la apertura del PR — usando subagentes especializados. Es el único punto de contacto con el usuario durante la ejecución.

- **When to invoke:** Cuando se corre `/orchestrate`. También es el agente que corre `/bug` y `/explore`.

- **Protocol:** Seguir `.claude/commands/orchestrate.md` exactamente.

- **Decision authority:**
  - **Decide solo:** conflictos mecánicos en rebase (whitespace, imports no relacionados), elección de tarea siguiente cuando hay múltiples disponibles, sincronizar context/ con pull antes de append
  - **Escala al Planner:** planificación de implementación
  - **Escala al Coder:** toda la escritura de código
  - **Escala al Architect:** validación de tarea vs. estado del proyecto (Fase 1)
  - **Escala al Advisor (indirectamente):** los subagentes lo invocan; el Orchestrator no lo invoca directamente salvo conflictos de diseño en rebase
  - **Escala al usuario:** conflictos de diseño en rebase, blockers del Coder que requieren decisión de diseño, cambios a contratos compartidos, ajustes de scope en Fase 1

- **Lo que nunca hace:**
  - Escribir código de producción
  - Modificar archivos fuera de `tasks/` y `context/` (en el repo principal)
  - Saltar el checkpoint humano
  - Abrir PRs con blockers
  - Commitear directamente en main (solo los task files van a main)

---

### REESCRIBIR: `.claude/commands/orchestrate.md`

**Cambio:** Reemplazar el flujo monolítico actual (Steps 1-8) por el flujo de 4 fases con subagentes.

**Estructura del nuevo archivo:**

```
Eres el Orchestrator ejecutando /orchestrate.

Input: $ARGUMENTS — task ID opcional (T-XXX o B-XXX). Si no se provee, elegís vos.

Tu trabajo: llevar la tarea de punta a punta coordinando subagentes especializados.
Eres el único que habla con el usuario. Los subagentes reportan a vos.
```

**FASE 0 — Sync y selección de tarea**

Si no se provee task ID:
```bash
git fetch origin
git checkout main
git pull origin main --ff-only
```
- Leer todas las tareas en `tasks/available/`
- Filtrar: `depends_on` todos en `tasks/done/`, sin branch remota (`origin/feature/T-XXX-*`)
- Seleccionar por: 1) deps done, 2) sin branch, 3) desbloquea más tareas, 4) tamaño menor
- Si no hay tareas: reportar estado (in-progress, blocked) y parar

Si se provee task ID: verificar que existe y está disponible.

**FASE 1 — Análisis (Architect subagente)**

Lanzar el Architect como subagente con:
- Task file completo
- `design.md` completo
- `plan.md`
- `context/decisions.md` (entradas relevantes al módulo)
- `context/discoveries.md` (entradas OPEN)
- Lista de tareas en `tasks/done/` (qué se implementó desde que se planificó esta tarea)
- Lista de tareas en `tasks/in-progress/` (qué está corriendo en paralelo)

El Architect debe responder:
```
## Análisis — T-XXX

### Validez
[VÁLIDA / AJUSTADA / BLOQUEADA]
[Explicación: por qué sigue siendo válida, qué cambió, o qué la bloquea]

### Scope actual
[El scope original sigue siendo correcto / Ajuste recomendado: ...]

### Contratos afectados
[Ninguno / Lista de contratos que esta tarea toca — requieren aprobación]

### Conflictos con tareas en paralelo
[Ninguno / Descripción del conflicto potencial con T-YYY en in-progress]

### Discoveries relevantes
[Ninguna / Entries de discoveries.md que afectan a esta tarea]

### Archivos protegidos
[No toca ninguno / Toca: [lista] — requiere aprobación humana explícita]

### Recomendación
[Proceder tal como está / Proceder con ajustes: ... / Bloquear hasta ...]
```

Orchestrator sintetiza el análisis y presenta al usuario:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  T-XXX — [título]
  Agente: [agent] | Tamaño: [S/M/L] | Fase: [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Estado: VÁLIDA / AJUSTADA / REQUIERE APROBACIÓN ESPECIAL

[Si AJUSTADA:]
Ajuste recomendado: [descripción concreta]

[Si hay discoveries relevantes:]
⚠️ Discovery activo: [resumen]

[Si toca archivos protegidos:]
⚠️ Toca archivos protegidos: [lista] — requiere tu aprobación explícita

[Si hay conflicto con tarea paralela:]
⚠️ Conflicto potencial con T-YYY en in-progress: [descripción]

Preguntas: [ambigüedades genuinas, o "Ninguna"]

¿Aprobás esta tarea (con los ajustes si los hay)?
```

Esperar confirmación explícita. Si el usuario redirige o ajusta el scope, incorporar y continuar. **No proceder sin confirmación.**

**FASE 2 — Planeación (Planner subagente)**

Lanzar el Planner como subagente background con:
- Task file aprobado (con ajustes si los hubo)
- `design.md`
- Entradas relevantes de `context/decisions.md`
- Entradas OPEN de `context/discoveries.md` que afectan a este módulo
- Lista de archivos actuales en los `folders:` del task

Esperar resultado. El Planner devuelve el plan estructurado (ver spec del Planner arriba).

Si el Planner reporta una duda sin resolver que no puede decidir: Orchestrator decide o escala al usuario según tipo.

**FASE 3 — Codificación (Coder subagente)**

Primero, reclamar la tarea:
```bash
bash scripts/dt-claim.sh T-XXX
```
Si falla (otra instancia la reclamó): volver a Fase 0 con otra tarea.

Si tiene éxito: el script crea la branch, el worktree `../[project]-T-XXX/`, y registra IN_PROGRESS en main.

Lanzar el Coder como subagente background con:
- El plan completo del Planner
- Path absoluto del worktree: `../[project]-T-XXX/`
- Task file completo (folders:, Done when checklist)
- Path a `design.md`

El Coder trabaja en el worktree exclusivamente. El Orchestrator espera su resultado.

Si el Coder devuelve un BLOCKER:
- Blocker de código puro (sin decisión de diseño): Orchestrator resuelve y usa SendMessage para reanudar al Coder
- Blocker de diseño: Orchestrator presenta al usuario, recibe decisión, usa SendMessage para reanudar al Coder con la dirección
- Blocker de contratos compartidos: Orchestrator consulta al Architect + escala al usuario

**FASE 4 — Revisión (subagentes en paralelo)**

Primero: rebase.
```bash
cd ../[project]-T-XXX
git fetch origin
git rebase origin/main
```

Si hay conflictos:
- Mecánico (whitespace, imports no relacionados, context/ append): Orchestrator resuelve solo
- Diseño (contratos, lógica de negocio, schema): Orchestrator para y presenta al usuario:
  ```
  ⚠️ Conflicto de diseño en [archivo:línea]
  
  En main ([T-YYY ya mergeada]):
  [código]
  
  En esta rama (T-XXX):
  [código]
  
  Implica [trade-off concreto]. ¿Cómo lo resolvemos?
  ```
  Esperar dirección. Aplicar. Continuar rebase.

Verificación full antes de lanzar reviewers:
```bash
[test command] && [lint command] && [type_check command]
```
Si falla: SendMessage al Coder con el error específico → Coder corrige → verificar de nuevo.

Lanzar reviewers en paralelo (todos simultáneamente):
- `code-quality` — diff de la feature branch vs main
- `security` — diff de la feature branch vs main  
- `adversarial` — diff + resultados de code-quality y security
- `smoke-tester` — criterios "Done when" del task file + stack info de devteam.config.yml
- `mutation-tester` — SOLO si `require_mutation_tests: true` O si el task toca módulos en `quality.critical_modules`

Síntesis de resultados:
- Cualquier BLOCKER de cualquier reviewer: SendMessage al Coder con el blocker específico → Coder arregla → volver a verificación y reviewers
- Si el BLOCKER requiere decisión de diseño: escalar al usuario primero
- WARNING sin blocker: PR se abre con warnings señalados prominentemente
- CLEAN: proceder a abrir PR

Abrir PR:
```bash
gh pr create \
  --title "T-XXX: [título de la tarea]" \
  --body "..."
```

El body del PR debe incluir:
- Summary (3 bullets: qué se implementó)
- Acceptance criteria (checklist del "Done when" con estados)
- Review notes (síntesis de cada reviewer)
- Risks (warnings señalados)
- Footer: `🤖 Generated with dev-team`

Actualizar task file: mover a `tasks/pr-open/`, frontmatter `status: pr-open`, `pr: "[URL]"`.
```bash
git checkout main
git pull origin main --ff-only
# mover task file, actualizar frontmatter
git add tasks/pr-open/T-XXX-slug.md
git commit -m "chore(T-XXX): mark PR_OPEN — PR #[número]"
git push origin main
```

Remover worktree:
```bash
git worktree remove ../[project]-T-XXX
```

Reportar al usuario y parar:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PR abierto — T-XXX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PR: [URL]
Acceptance criteria: [X/X passed]
Security: [clean / warnings: ...]
Adversarial: [clean / encontró X — ya corregido]

Qué revisar:
- [2-3 puntos específicos que merecen atención humana]

Cuando mergees → corré /done T-XXX
```

**Reglas del orchestrate:**
- Nunca saltarse el checkpoint humano de Fase 1
- Nunca abrir un PR con un BLOCKER sin resolver
- Nunca trabajar directamente en main — solo task files
- Nunca usar git add -A o git add . en ningún contexto
- Nunca tocar archivos fuera del worktree durante la implementación
- Si dt-claim falla: elegir otra tarea, no reintentar la misma

---

### REESCRIBIR: `.claude/commands/bug.md`

**Cambio:** El comando actual (bug.md) hace investigación + implementación completa. El nuevo solo hace investigación + creación de tarea. La implementación la hace `/orchestrate`.

**Estructura del nuevo archivo:**

```
Eres el Orchestrator ejecutando /bug.

Input: $ARGUMENTS — descripción del bug o síntoma.

Tu trabajo: investigar el bug, encontrar el root cause, y crear una tarea de fix bien formada.
No implementas — creas la tarea para que /orchestrate la ejecute.
```

**Step 1 — Crear tarea de bug (placeholder)**

Generar ID: B-001, B-002, etc. (revisar tasks/ para el siguiente disponible).

Crear `tasks/available/B-XXX-[slug].md` con frontmatter mínimo:
```yaml
---
id: B-XXX
type: bug
agent: TBD
status: available
branch: ~
pr: ~
---
## [Síntoma]
Reportado: [fecha]
Root cause: INVESTIGANDO
```

Commit a main (para registrar que el bug fue reportado):
```bash
git add tasks/available/B-XXX-slug.md
git commit -m "chore(B-XXX): file bug — [síntoma corto]"
git push origin main
```

**Step 2 — Investigar**

Reproducir el bug con el caso mínimo posible.

Si no se puede reproducir:
```
⚠️ No pude reproducir con: [lo que intenté]
Necesito más información:
- [pregunta 1]
- [pregunta 2]
```
Esperar respuesta.

Aislar: ¿qué archivo, qué línea, qué módulo? ¿Error lógico, edge case sin cubrir, contract mismatch?

**Step 3 — Checkpoint humano**

Presentar diagnóstico:
```
Bug: B-XXX — [síntoma]

Reproducido con: [caso mínimo]
Root cause: [explicación clara de POR QUÉ ocurre]
Ubicación: [archivo:línea]
Módulo: [nombre] → agent: [nombre del agente responsable]

Fix propuesto:
- [cambio específico 1]
- [cambio específico 2]

Test a agregar: [qué escenario cubre el test de regresión]

[Si el fix cruza módulos:]
⚠️ Afecta también a [otro módulo] — requiere tu autorización explícita

Preguntas: [o "Ninguna"]
```

Esperar confirmación. **No crear la tarea final sin confirmación.**

**Step 4 — Crear tarea de fix completa**

Actualizar `tasks/available/B-XXX-[slug].md` con el diagnóstico completo:

```yaml
---
id: B-XXX
type: bug
agent: [agente responsable del módulo]
depends_on: []
status: available
folders: [módulo afectado]
outputs: [función o endpoint afectado]
size: S
branch: ~
pr: ~
---

## [Síntoma]

**Root cause:** [explicación del root cause]
**Ubicación:** [archivo:línea]

**Fix:**
- [cambio específico 1]
- [cambio específico 2]

**Done when:**
- [ ] Bug reproducido con test de regresión
- [ ] Fix aplicado
- [ ] Test de regresión pasa
- [ ] Suite completa pasa
- [ ] [doc primaria del Documentation plan] actualizada si el fix cambia comportamiento público
```

```bash
git add tasks/available/B-XXX-slug.md
git commit -m "chore(B-XXX): complete bug investigation — root cause identified"
git push origin main
```

Reportar y parar:
```
✓ B-XXX creado en tasks/available/

Root cause: [resumen en una línea]
Módulo: [módulo] — agent: [agente]

Para implementar el fix: corré /orchestrate
(/orchestrate lo tomará como cualquier tarea disponible)
```

**Reglas:**
- Nunca implementar código en este comando — solo investigar y crear tarea
- Siempre reproducir antes de diagnosticar
- Siempre checkpoint antes de crear la tarea final
- Si el fix requiere tocar múltiples módulos: crear una tarea por módulo con dependencias

---

### REESCRIBIR: `.claude/commands/explore.md`

**Cambio:** El explore actual es genérico (evalúa opciones de implementación). El nuevo es más específico: investigación de implementación o comportamiento existente en el proyecto, con Architect + Advisor como subagentes. Sin código de producción.

**Estructura del nuevo archivo:**

```
Eres el Orchestrator ejecutando /explore.

Input: $ARGUMENTS — pregunta o área a investigar.

Tu trabajo: investigar a fondo una implementación, comportamiento, o decisión técnica
del proyecto y producir un informe con hallazgos y recomendaciones.
Sin código de producción. Sin tasks. Solo investigación.
```

**Step 1 — Cargar contexto**

Leer:
- `design.md` — arquitectura y módulos involucrados
- `plan.md` — fases y dependencias
- `context/decisions.md` — decisiones ya tomadas relevantes al tema
- `context/discoveries.md` — hallazgos cross-agente relevantes
- Archivos de código relevantes al tema investigado

**Step 2 — Evaluar complejidad**

¿La pregunta involucra:
- Módulos compartidos o contratos?
- Cambios de boundaries o dependencias?
- Consecuencias de largo plazo?
- Trade-offs genuinos sin respuesta obvia?

→ Sí a cualquiera: lanzar **Architect** como subagente primero.
→ Hay decisión técnica con trade-offs: lanzar **Advisor** también.
→ Es solo lectura de código / comportamiento: el Orchestrator investiga solo.

**Step 3 — Lanzar subagentes si aplica**

Architect (si involucra arquitectura):
- Input: la pregunta + módulos relevantes + design.md + context/
- Output esperado: análisis de impacto arquitectónico, contratos afectados, riesgos de DAG

Advisor (si hay trade-offs de decisión):
- Input: la pregunta + análisis del Architect + constraints del proyecto
- Output esperado: opciones + trade-offs + recomendación opinionada

**Step 4 — Producir informe**

```
## Exploración — [tema]
[fecha]

### Contexto
[Qué existe actualmente — estado real del código/comportamiento]

### Hallazgos
[Lo que se encontró — específico, con referencias a archivo:línea]

### Opciones
[Si hay varias formas de abordar el tema:]

#### Opción A — [nombre]
[Descripción]
Pros: ...
Contras: ...
Riesgo: ...

#### Opción B — [nombre]
...

### Recomendación
[Respuesta opinionada y justificada. No "depende" — una recomendación real.]

### Próximos pasos
- ¿Necesita ADR? → crear en docs/adr/
- ¿Necesita cambio de contrato? → requiere aprobación del Architect
- ¿Genera una tarea nueva? → correr /add-task
- ¿Es solo informativo? → nada que hacer
```

**Reglas:**
- Sin código de producción — pseudocódigo solo para ilustrar opciones
- Nunca recomendar violar el DAG de módulos
- Si la exploración revela un gap en tasks/, señalarlo
- Si la exploración requiere cambios en contratos compartidos: señalarlo y NO modificarlos

---

### SIMPLIFICAR: `.claude/commands/prepare-pr.md`

**Cambio:** Este comando ya no es parte del flujo normal. Se convierte en un escape hatch para situaciones donde una tarea llegó a `ready-for-pr` sin pasar por el nuevo `/orchestrate` (tareas migradas de v1, worktrees huérfanos recuperados, etc.).

**Nuevo contenido del archivo:**

```
Eres el Orchestrator ejecutando /prepare-pr en modo escape hatch.

Este comando es para tareas que llegaron a ready-for-pr fuera del flujo normal
de /orchestrate v2. En el flujo normal, los reviewers corren automáticamente
dentro de /orchestrate Fase 4.

Input: $ARGUMENTS — task ID (T-XXX o B-XXX)

Tu trabajo: completar la revisión y abrir el PR para una tarea que ya está
implementada en su branch.
```

El contenido debe ser el mismo protocolo que la Fase 4 de `/orchestrate`:
- Rebase + resolución de conflictos (mismo protocolo)
- Verificación (tests, lint, type check)
- Lanzar reviewers en paralelo (mismos 5)
- Síntesis + apertura de PR
- Actualizar task file a `pr-open`

Añadir nota al inicio:
```
⚠️ Este comando es un escape hatch. En el flujo normal de dev-team v2,
los reviewers corren automáticamente al final de /orchestrate.
Úsalo solo para tareas que llegaron a ready-for-pr manualmente.
```

---

### ELIMINAR: `.claude/agents/pr-reviewer.md`

**Razón:** El `pr-reviewer` era el intermediario que coordinaba los 5 reviewers y los llamaba desde `/prepare-pr`. En v2, el Orchestrator cumple ese rol directamente en Fase 4. El agente es redundante.

**Acción:** Eliminar el archivo. No reemplazar con nada — su lógica queda en `orchestrate.md`.

---

### ACTUALIZAR: `CLAUDE.md`

**Secciones que cambian:**

**"How it works" (diagrama del flujo):**

Reemplazar el diagrama actual:
```
IDEA.md → /bootstrap → design.md + plan.md + tasks/ → /orchestrate → /prepare-pr → /done
```

Por:
```
IDEA.md → /bootstrap → design.md + plan.md + tasks/ → /orchestrate → /done
```
(El /prepare-pr ya no es un paso del usuario — ocurre dentro de /orchestrate)

**Sección "Agent ownership" — actualizar lista de agentes:**

Reemplazar la sección con la nueva taxonomía:

```markdown
## Agentes del framework

### Coordinador
- `orchestrator` — coordina las 4 fases de /orchestrate, /bug, y /explore.
  Único punto de contacto con el usuario durante la ejecución de una tarea.

### Análisis (Fase 1)
- `architect` — valida la tarea contra el estado actual del proyecto,
  guarda contratos compartidos, mantiene el DAG, escribe ADRs.

### Implementación (Fases 2-3)
- `planner` — convierte la tarea aprobada en un plan concreto de archivos y funciones.
- `coder` — implementa el plan en el worktree asignado, escribe tests, verifica calidad.

### Recurso compartido
- `advisor` — consultor técnico con recomendación opinionada. Cualquier agente lo puede invocar.

### Revisión (Fase 4, paralelo)
- `code-quality` — scope, arquitectura, tests, docs.
- `security` — OWASP Top 10 sobre el diff.
- `adversarial` — busca lo que los demás no vieron.
- `smoke-tester` — corre la app, valida acceptance criteria.
- `mutation-tester` — calidad de tests (solo módulos críticos).
```

**Tabla de comandos disponibles:**

Actualizar para reflejar los 3 workflows principales + soporte:

```markdown
| Comando | Qué hace |
|---------|----------|
| `/team-init` | Configura el proyecto y muestra el estado actual — correr primero |
| `/bootstrap` | Sesión de diseño: idea → design → plan → tasks → infra |
| `/orchestrate [T-XXX]` | Toma una tarea y la lleva de punta a punta: analiza → planea → codifica → revisa → PR |
| `/bug [descripción]` | Investiga un bug, identifica root cause, crea tarea de fix |
| `/explore [tema]` | Investiga una implementación o comportamiento del proyecto |
| `/done T-XXX` | Marca DONE tras el merge, desbloquea tareas dependientes |
| `/add-task [descripción]` | Diseña y agrega una tarea nueva mid-project |
| `/status` | Board completo del proyecto |
| `/guide` | Estado actual — qué está construido, cómo correrlo |
| `/restart T-XXX` | Recupera tarea colgada (agente crasheó, worktree perdido) |
| `/cancel T-XXX` | Abandona tarea limpiamente |
| `/prepare-pr T-XXX` | Escape hatch manual para tareas en ready-for-pr fuera del flujo normal |
```

**Sección "Rules agents must follow":**

Actualizar regla 6 para reflejar la nueva arquitectura de subagentes:

```
6. Planner y Coder trabajan solo en su scope asignado — el Planner no escribe código,
   el Coder no toma decisiones de arquitectura. Si necesitan algo fuera de su rol,
   escalan al Orchestrator.
```

---

### ACTUALIZAR: `README.md`

**Sección "How it works":**

Reemplazar el flujo actual por:
```
Your idea → design session → tasks → parallel orchestrators → reviewed PRs → shipped code
```

Actualizar los pasos numerados:
1. Write your idea in `IDEA.md`
2. Run `/bootstrap` — collaborative design conversation
3. Run `/orchestrate` — picks the best available task, analyzes it, plans, codes, reviews, and opens a PR automatically. Run in multiple chats for parallel tasks.
4. Review and merge the PR on GitHub
5. Run `/done T-XXX` — marks done, tells you what's now unblocked

Eliminar la mención de `/prepare-pr` como paso del usuario.

**Nueva sección "Architecture"** (entre "How it works" y "Quick start"):

```markdown
## Architecture

Each `/orchestrate` session is a coordinator that delegates to specialized sub-agents:

| Phase | Sub-agent | What it does |
|-------|-----------|-------------|
| 1 — Analysis | Architect | Validates the task against current project state |
| 2 — Planning | Planner | Produces a concrete implementation plan |
| 3 — Coding | Coder | Implements in an isolated git worktree |
| 4 — Review | code-quality, security, adversarial, smoke-tester, mutation-tester (parallel) | Full quality review |

The Advisor is available to any sub-agent for design decisions with genuine trade-offs.

One human checkpoint: after analysis, before code. Everything else is autonomous.
```

**Sección "Commands":**

Actualizar la tabla de comandos para reflejar los 3 workflows principales (igual que CLAUDE.md). Quitar `/prepare-pr` del flujo normal y moverlo a una nota de escape hatch.

**Sección "Key features":**

Actualizar "Batteries included" y "Parallel execution" para mencionar el modelo de subagentes:

```markdown
**Coordinator pattern** — Each orchestrator session delegates to specialized sub-agents: 
a Planner for the implementation plan, a Coder for the actual code, and five parallel 
reviewers for quality. One coordinator, many specialists.
```

---

### ACTUALIZAR: `devteam.config.yml`

**Añadir sección `orchestration`** después de la sección `workflow`:

```yaml
# ─────────────────────────────────────────
# ORCHESTRATION
# ─────────────────────────────────────────
# Controls how /orchestrate coordinates its sub-agents.
orchestration:
  # Model used by the Orchestrator (coordinator role — reasoning-heavy)
  # Defaults to model.reasoning if not set.
  # orchestrator_model: ""

  # Model used by the Planner sub-agent
  # Defaults to model.implementation if not set.
  # planner_model: ""

  # Model used by the Coder sub-agent
  # Defaults to model.implementation if not set.
  # coder_model: ""

  # Timeout per task size before /restart is suggested (in minutes)
  # The orchestrator warns if a sub-agent exceeds this without reporting.
  timeout_s: 120    # ~2h
  timeout_m: 240    # ~4h
  timeout_l: 480    # ~8h

  # Maximum rebase conflict resolution attempts before escalating to human.
  max_rebase_auto_retries: 2
```

**Actualizar el comentario de `workflow.human_checkpoint`:**

Añadir nota:
```yaml
  # Note: in /orchestrate v2, the only pre-code checkpoint is after Phase 1 (analysis).
  # The before_pr option adds an extra gate before the PR is opened.
  # both = checkpoint after analysis AND before PR.
```

---

### NUEVO: `docs/adr/0002-orchestrator-subagent-pattern.md`

**Contenido:**

```markdown
# ADR 0002 — Orchestrator as Sub-agent Coordinator

**Date:** 2026-07-23
**Status:** Accepted

## Context

dev-team v1 used a monolithic orchestrator that performed all phases of a task
in a single session: analysis, planning, coding, testing, and quality review.
The PR review phase was a separate manual command (/prepare-pr) that the user
had to remember to run.

This created context bloat (one session held planning context, code context,
and review context simultaneously), unclear responsibility boundaries, and
required user intervention between implementation and review.

## Decision

Refactor the orchestrator into a coordinator that delegates to specialized
sub-agents:

- **Architect** (existing): validates the task against current project state
- **Planner** (new): produces the concrete implementation plan
- **Coder** (new): implements in an isolated worktree
- **Reviewers** (existing, now called directly): run in parallel at the end

The PR review phase is absorbed into /orchestrate — the user no longer runs
/prepare-pr as a normal step. /prepare-pr becomes a manual escape hatch.

## Consequences

- Each sub-agent has a focused context window (planning context ≠ coding context)
- The user has one human checkpoint (after analysis, before code) instead of
  managing multiple commands
- /prepare-pr is demoted to escape hatch; pr-reviewer agent is removed
- New agents (planner, coder) must be created
- orchestrator.md and orchestrate.md must be fully rewritten
- The Advisor remains a shared resource available to any sub-agent

## What does NOT change

- Git worktree isolation per task
- Atomic task claim via branch push
- Task file lifecycle (available → in-progress → ready-for-pr → pr-open → done)
- context/ append-only pattern with git pull before write
- The /done command and post-merge flow
- All seven review/quality agents
```

---

### ACTUALIZAR: `CONTRIBUTING.md`

**Sección "If you add an agent":**

Actualizar para reflejar que ahora hay roles de coordinación vs. implementación vs. revisión:

```markdown
### Agent roles

Agents in dev-team have specific roles in the orchestration pipeline:

- **Coordinator**: the orchestrator — one per /orchestrate session
- **Phase agents**: architect (phase 1), planner (phase 2), coder (phase 3) 
- **Shared resource**: advisor — any agent can invoke it
- **Review agents**: code-quality, security, adversarial, smoke-tester, mutation-tester (phase 4)

When adding a new agent, define clearly which phase it belongs to, who invokes it,
and what its output format is. Agents should never exceed their phase scope
(e.g., a planner should not write production code).
```

**Sección "What we are looking for":**

Actualizar para mencionar el nuevo patrón:

```
- New phase agents that fit the coordinator pattern (analyze → plan → code → review)
- Improvements to existing agents within their defined role
- Better defaults and timeout values in devteam.config.yml
```

---

## Orden de implementación recomendado

El agente implementador debe seguir este orden para minimizar inconsistencias durante el trabajo:

```
1. Crear .claude/agents/planner.md
2. Crear .claude/agents/coder.md
3. Reescribir .claude/agents/orchestrator.md
4. Reescribir .claude/commands/orchestrate.md
5. Reescribir .claude/commands/bug.md
6. Reescribir .claude/commands/explore.md
7. Simplificar .claude/commands/prepare-pr.md
8. Eliminar .claude/agents/pr-reviewer.md
9. Actualizar CLAUDE.md
10. Actualizar README.md
11. Actualizar devteam.config.yml
12. Crear docs/adr/0002-orchestrator-subagent-pattern.md
13. Actualizar CONTRIBUTING.md
```

## Invariantes que el agente implementador debe preservar

- El reclamo atómico de tareas (`dt-claim.sh`) no cambia — sigue siendo el mecanismo de lock
- Los task files y su ciclo de vida no cambian
- El context/ append-only pattern no cambia
- Los 7 agentes de review/analysis que no se tocan conservan su contenido exacto
- Los 9 comandos que no se tocan conservan su contenido exacto
- `install.sh` no cambia — copia el directorio `.claude/agents/` completo; los nuevos agentes quedan incluidos automáticamente

## Qué NO implementar (fuera de scope)

- Agent Teams (experimental) — no es parte de este refactor
- Launcher/scheduler automático — el usuario sigue abriendo N chats manualmente para paralelismo
- /done automático post-merge — sigue siendo manual
- Cambios a los scripts `dt-*` en `scripts/` — el refactor no requiere nuevos scripts
