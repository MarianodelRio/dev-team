# dev-agent — Diseño de solución

## Qué es dev-agent

**dev-agent** es un sistema de agente único orientado a contribuir en proyectos existentes con equipos de desarrollo. A diferencia de dev-team, que gestiona un proyecto completo desde una idea, dev-agent resuelve una sola tarea a la vez: llegas a un repositorio ya en marcha, describes lo que necesitas hacer, y el agente produce un PR que encaja con las convenciones del equipo.

**El problema que resuelve:** los developers en proyectos existentes no necesitan bootstrapping, ni DAG de dependencias, ni gestión de fases multi-tarea. Necesitan implementar una cosa, bien, rápido, y que el resultado sea un PR que sus compañeros puedan revisar sin fricción.

**Diferencia fundamental con dev-team:**

| | dev-team | dev-agent |
|---|---|---|
| Alcance | Proyecto completo | Una tarea |
| Contexto | Greenfield o brownfield controlado | Brownfield por defecto |
| Setup | `/bootstrap` obligatorio | Zero setup en el repo destino |
| Artefactos | design.md + spec.md + plan.md + tasks/ | task.md efímero por sesión |
| Paralelismo | Múltiples tareas coordinadas vía DAG | Una sesión = una tarea |
| Estado entre sesiones | context/decisions/, context/discoveries/ | No persiste |
| Orientación | Eres el dueño del proyecto | Eres un contributor más |

---

## Filosofía

Un comando, una tarea, un branch, un PR. Zero setup en el repo destino. El agente descubre las convenciones del proyecto automáticamente, ejecuta el flujo elegido según la complejidad de la tarea, y abre un PR que encaja con el equipo.

Los conflictos con otros developers (o con otras instancias de dev-agent) se resuelven en el rebase pre-PR, igual que con cualquier developer trabajando en su rama.

---

## Las tres variantes

```
one-shot:  [context.md / scout] → code → review(rápido) → PR
standard:  [context.md / scout] → spec → ✋ → plan → code → review(completo) → PR
hardened:  [context.md / scout] → spec → ✋ → plan → code → clean → review(completo) → mutate → PR
```

✋ = checkpoint humano obligatorio

| Variante | Cuándo usarla | Ejemplos |
|---|---|---|
| **one-shot** | Tarea completamente definida, bajo riesgo | Hotfix, typo, config change, endpoint pequeño |
| **standard** | Complejidad media, algo de ambigüedad | Feature nueva, refactor, integración |
| **hardened** | Código crítico o sensible | Auth, pagos, APIs públicas, exportación de datos |

La variante se especifica en el comando o en la configuración del proyecto. No es un parámetro global fijo: una misma sesión puede usar `one-shot` para un fix y `hardened` para el módulo de pagos.

---

## Flujo detallado por variante

### one-shot

```
1. Contexto      lee .dev-agent/context.md si existe; si no, Scout inline → lo cachea
2. Orchestrator  da-worktree.sh create "[descripción]" → crea worktree + branch
                 presenta resumen de lo que va a hacer, pide confirmación
3. Coder         implementa en worktree, escribe tests
                 da-verify.sh → test+lint+types
4. [Paralelo]    code-quality + security
5. Orchestrator  sintetiza reviews, gestiona retries
                 da-rebase.sh → rebase + resolución de conflictos
                 da-pr.sh → abre PR desde task.md
                 da-worktree.sh remove → destruye worktree
```

No hay spec formal ni plan estructurado. El Coder recibe la descripción original, el Repo Context y las instrucciones del Orchestrator sobre qué cambiar exactamente.

### standard

```
1. Contexto      lee .dev-agent/context.md si existe; si no, Scout inline → lo cachea
2. Orchestrator  da-worktree.sh create "[descripción]" → crea worktree + branch
3. Specifier     escribe spec Gherkin + scope + out-of-scope + Done when
                 da-task.sh init → crea task.md con frontmatter
4. ✋ Checkpoint  humano aprueba spec — puede ajustar, Specifier refina y vuelve a presentar
5. Planner       plan fichero-por-fichero + orden de implementación + tests requeridos
                 da-task.sh status planning → actualiza estado
6. Coder         implementa en worktree, escribe tests
                 da-verify.sh → test+lint+types
                 da-task.sh status coding → actualiza estado
7. [Paralelo]    code-quality + security + adversarial*
8. Orchestrator  sintetiza reviews, gestiona retries
                 da-rebase.sh → rebase + resolución de conflictos
                 da-verify.sh → verificación final
                 da-pr.sh → abre PR desde task.md
                 da-worktree.sh remove → destruye worktree
```

*adversarial activa solo si code-quality y security aprueban por unanimidad

### hardened

```
1. Contexto      lee .dev-agent/context.md si existe; si no, Scout inline → lo cachea
2. Orchestrator  da-worktree.sh create "[descripción]" → crea worktree + branch
3. Specifier     spec Gherkin extendida: escenarios de edge cases y failure modes
                 da-task.sh init → crea task.md con frontmatter
4. ✋ Checkpoint  humano aprueba spec
5. Planner       plan + marca funciones críticas para mutation-tester
                 da-task.sh status planning → actualiza estado
6. Coder         implementa en worktree, escribe tests
                 da-verify.sh → test+lint+types
                 da-task.sh status coding → actualiza estado
7. Cleaner       CRAP gate: reduce complejidad, extrae funciones largas, mejora naming
                 da-verify.sh → verifica que no rompió nada tras cada cambio
                 da-task.sh status cleaning → actualiza estado
8. [Paralelo]    code-quality + security + adversarial* + smoke-tester + mutation-tester
9. Orchestrator  sintetiza reviews, gestiona retries
                 da-rebase.sh → rebase + resolución de conflictos
                 da-verify.sh → verificación final
                 da-pr.sh → abre PR desde task.md
                 da-worktree.sh remove → destruye worktree
```

---

## Gestión de conflictos

Los worktrees resuelven los conflictos locales: cada instancia de dev-agent trabaja en `../[repo]-[slug]/`, completamente aislada del repo principal y de cualquier otra instancia.

Los conflictos con otros developers o con otras instancias de dev-agent se capturan en el rebase pre-PR, que ocurre siempre antes de abrir el PR:

```
git fetch origin
git rebase origin/main
  → conflicto mecánico (whitespace, imports, reordenación)
    → Orchestrator resuelve solo
  → conflicto de lógica (misma función modificada de formas distintas)
    → escala al usuario con contexto exacto del conflicto
  → limpio
    → test && lint && type_check
    → gh pr create
```

No hay detección temprana de conflictos porque los conflictos pueden venir de cualquier fuente (otros developers humanos, CI, otras ramas), así que un sistema de advertencia solo tendría falsos negativos. El rebase lo captura todo.

---

## Contexto de proyecto

El Repo Context es el input que todos los agentes comparten: stack, convenciones, comandos, estructura de tests. Hay dos formas de obtenerlo, con la misma lógica de decisión al inicio de cada `/agent`:

```
¿existe .dev-agent/context.md?
  Sí → leerlo directamente (rápido, sin I/O adicional)
  No → ejecutar Scout inline → guardar resultado en .dev-agent/context.md
```

### El Scout (inline)

Cuando no existe `.dev-agent/context.md`, el Orchestrator lo genera leyendo el repo antes de delegar a ningún sub-agente. Lee en este orden:

```
CLAUDE.md                            instrucciones del proyecto (si existe)
README.md                            overview del proyecto
package.json                         stack, scripts de test/lint/build (Node/TS)
pyproject.toml / setup.cfg           stack, dependencias, config de herramientas (Python)
go.mod                               módulo y dependencias (Go)
Cargo.toml                           dependencias (Rust)
pom.xml / build.gradle               dependencias (Java/Kotlin)
.github/PULL_REQUEST_TEMPLATE.md     formato de PR esperado por el equipo
.eslintrc / ruff.toml / .golangci    configuración de linting
tests/ o test/                       lee 2-3 ficheros como ejemplo de convenciones de test
src/ o lib/                          lee 2-3 ficheros del módulo más relevante para la tarea
devagent.config.yml                  configuración de dev-agent en el proyecto (si existe)
```

Produce `.dev-agent/context.md` con el **Repo Context** estructurado:

```markdown
# Repo Context
Generado: 2026-08-10T10:30:00Z

Stack: Python 3.11, FastAPI, SQLAlchemy
Test runner: pytest — fixtures en tests/conftest.py
Test structure: unit en tests/unit/, integration en tests/integration/
Lint: ruff + mypy strict
Commands:
  test: pytest
  lint: ruff check . && mypy .
  type_check: mypy .
PR template: .github/PULL_REQUEST_TEMPLATE.md existe
Convenciones detectadas:
  - snake_case en todo el código
  - repositories en src/[module]/repository.py
  - schemas en src/[module]/schemas.py
  - no lógica de negocio en routers
  - tests nombrados como test_[función]_[escenario]
```

Si `devagent.config.yml` existe, se usa como base y el Scout solo infiere los campos no definidos.

### La skill `/setup`

Permite generar o regenerar el Repo Context explícitamente, sin necesidad de lanzar una tarea. Útil para:
- Primera vez que se usa dev-agent en un repo
- Después de cambios significativos en el proyecto (nueva herramienta de lint, nueva estructura de tests)
- Cuando el Scout infirió algo incorrectamente y hay que regenerarlo

```bash
/setup           genera .dev-agent/context.md (o lo regenera si ya existe)
/setup --print   muestra el contexto generado sin guardar
```

El fichero `.dev-agent/context.md` está en `.gitignore` — es contexto local de la máquina, no del repositorio. Cada developer genera el suyo. Si el equipo quiere estandarizar valores concretos (comandos de test, umbrales de calidad), eso va en `devagent.config.yml` (que sí se commitea).

---

## El artefacto central: `task.md`

Un único fichero por sesión. Vive en el worktree durante la ejecución. Su contenido alimenta el PR description al final. No persiste en el repo destino tras la sesión.

```markdown
---
variant: standard
status: coding
branch: feature/add-user-csv-export
---

## Tarea
[descripción original del usuario]

## Repo Context
Stack: Python 3.11, FastAPI
Test runner: pytest — fixtures en tests/conftest.py
Lint: ruff + mypy
PR template: .github/PULL_REQUEST_TEMPLATE.md existe
Convenciones: snake_case, repositories en src/[module]/repository.py

## Spec
### Scope
Folders: src/users/, tests/unit/users/, tests/integration/
Fuera de scope: email delivery, formato Excel, paginación

### Acceptance Criteria
```gherkin
Feature: Exportación de usuarios a CSV

  Scenario: Admin exporta todos los usuarios
    Given estoy autenticado como admin
    When envío GET /users/export
    Then recibo status 200
    And el Content-Type es text/csv
    And el CSV contiene una fila por usuario

  Scenario: Petición sin autenticación rechazada
    Given no estoy autenticado
    When envío GET /users/export
    Then recibo status 401
```

### Done when
- [ ] GET /users/export devuelve 200 con CSV
- [ ] Peticiones sin auth devuelven 401
- [ ] CSV incluye: id, email, created_at, role
- [ ] Tests unitarios para la lógica de generación CSV
- [ ] Test de integración para el endpoint

## Plan
### Crear
- `src/users/export.py` — lógica de generación CSV
- `tests/unit/users/test_export.py` — unit tests

### Modificar
- `src/users/router.py` — añadir endpoint GET /export
- `src/users/schemas.py` — añadir ExportRow schema

### Orden de implementación
1. schemas.py (sin dependencias)
2. export.py (depende de schemas)
3. router.py (depende de export)
4. tests junto a cada paso

### Funciones críticas (hardened only)
- `export.generate_csv()` — maneja datos de usuarios, lógica de escape de caracteres

## Implementation Notes
[el Coder escribe aquí decisiones no obvias durante la implementación]

## Review Results
[el Orchestrator escribe aquí tras el review]
```

El campo `status` evoluciona a lo largo de la sesión:
`specifying` → `planning` → `coding` → `cleaning` → `reviewing` → `done`

---

## Los agentes

### Orchestrator (el comando en sí)

Coordina todas las fases. Único punto de contacto con el usuario durante la sesión. No escribe código de producción ni toma decisiones de diseño sin confirmación humana.

Responsabilidades:
- Resolver el Repo Context: leer `.dev-agent/context.md` o ejecutar Scout inline
- Llamar a `da-config.sh` para obtener la configuración fusionada al inicio
- Llamar a `da-worktree.sh create` para crear el worktree y el branch
- Llamar a `da-task.sh init` para crear task.md, y `da-task.sh status` para actualizarlo
- Lanzar sub-agentes en el orden correcto según la variante
- Presentar el checkpoint y esperar aprobación
- Llamar a `da-verify.sh` tras el Coder, tras el Cleaner, y antes del PR
- Llamar a `da-rebase.sh` pre-PR y resolver el resultado según el tipo de conflicto
- Sintetizar resultados del review y gestionar retries
- Llamar a `da-pr.sh` para abrir el PR desde task.md
- Llamar a `da-worktree.sh remove` para destruir el worktree al final

Escala al usuario cuando:
- Conflicto de rebase de lógica (no mecánico)
- BLOCKER de security (sin auto-retry)
- BLOCKER tras agotar los retries configurados
- Decisión de diseño que afecta a contratos compartidos

### Specifier

Recibe: descripción de la tarea + Repo Context.

Produce:
- Spec en formato Gherkin (Feature + Scenarios con Given/When/Then)
- Scope: carpetas que se van a tocar
- Out of scope: qué no hace esta tarea deliberadamente
- Checklist `Done when` con criterios verificables por el smoke-tester

En `hardened`: añade escenarios adicionales de edge cases (inputs vacíos, límites, concurrencia) y failure modes (timeouts, servicios caídos, datos malformados).

Si la tarea es ambigua: hace un máximo de 3 preguntas antes de escribir la spec. No empieza a escribir con información insuficiente.

### Planner

Recibe: spec aprobada + Repo Context + ficheros actuales de los módulos relevantes para la tarea.

Produce:
- Ficheros a crear (con propósito de cada uno)
- Ficheros a modificar (con descripción del cambio)
- Orden de implementación (dependencias entre ficheros)
- Tests requeridos (tipo y ubicación, siguiendo las convenciones del proyecto)
- Decisiones de diseño no obvias (por qué esta estructura y no otra)

En `hardened`: marca las funciones que manejan lógica crítica para que el mutation-tester las priorice.

No escribe código. Si detecta que la tarea requiere tocar algo fuera del scope definido en la spec, lo reporta al Orchestrator en lugar de ampliarlo silenciosamente.

### Coder

Trabaja exclusivamente en el worktree (`../[repo]-[slug]/`). Nunca toca el repo principal.

Sigue las convenciones del proyecto tal como aparecen en el Repo Context, no sus propias preferencias. Si las convenciones del proyecto contradicen sus estándares habituales, prevalecen las del proyecto.

Estándares de implementación:
- Funciones de menos de 40 líneas
- Early returns en lugar de nesting profundo
- Constantes nombradas, sin magic numbers
- Error handling explícito (los errores nunca se silencian)
- No N+1 en consultas
- Operaciones sobre colecciones grandes siempre acotadas
- Queries parametrizadas (nunca interpolación de strings en SQL)
- Sin secrets hardcodeados, sin datos sensibles en logs
- Lógica de negocio en la capa de servicio, no en routers ni repositorios
- Inyección de dependencias

Escribe tests junto al código, no después. Antes de reportar done ejecuta `test && lint && type_check` y no avanza hasta que pasan.

Cada commit termina con `By coder.` en el mensaje.

Si toma una decisión no obvia durante la implementación, la escribe en `## Implementation Notes` del task.md con el razonamiento.

Si encuentra un BLOCKER real (algo que no puede resolver sin información o decisión externa), reporta al Orchestrator con contexto completo: qué bloqueó, qué intentó, qué información necesita.

### Cleaner (hardened only)

Recibe: diff de lo que produjo el Coder.

Objetivo: mejorar, no juzgar. El Cleaner actúa antes del review, no después.

Gate obligatorio: CRAP score ≤ umbral configurable (default 15) por función. Si una función supera el umbral, la refactoriza hasta cumplirlo. No avanza al review hasta que el gate pasa.

Acciones:
- Extrae funciones que superan ~40 líneas en funciones más pequeñas con nombres descriptivos
- Mejora nombres de variables y funciones si no son autodescriptivos
- Elimina dead code (código que no se ejecuta nunca)
- Reduce nesting transformando condiciones en early returns
- No cambia lógica de negocio bajo ninguna circunstancia

Pasa `test && lint` tras cada cambio para verificar que no rompió nada.

Cada commit termina con `By cleaner.`

Si tras 2 intentos no puede cumplir el gate, reporta al Orchestrator con las funciones problemáticas y el razonamiento.

### Code-quality

Analiza el diff completo de la tarea. Veredicto: `APPROVED / WARNINGS / BLOCKED`.

Revisa:
- **Scope**: solo se tocaron las carpetas del plan — cualquier fichero fuera del scope es BLOCKER
- **Correctness**: tipos de retorno correctos, error handling explícito, no silent failures, no dead code
- **Tests**: tipo correcto según las convenciones del proyecto, no vacuos (assertions significativas), cubren happy path y edges relevantes, independientes entre sí
- **Docs**: si se añade superficie pública (endpoint, función exportada, comando CLI), la documentación correspondiente está actualizada
- **Claridad**: nombres descriptivos, funciones no excesivamente largas, sin nesting innecesario
- **Observabilidad**: errores con contexto suficiente, niveles de log correctos, sin datos sensibles en logs
- **Performance**: sin N+1, sin operaciones no acotadas sobre colecciones grandes

Severidades: `BLOCKER` (bloquea el PR) / `WARNING` (debe constar en el PR) / `NITPICK` (opcional, no bloquea).

### Security

Analiza únicamente el diff de la tarea (no el repo completo). Veredicto: `CLEAN / WARNINGS / BLOCKED`.

Cubre OWASP Top 10:
- A01 Broken Access Control: endpoints sin verificación de permisos, escalación de privilegios
- A02 Cryptographic Failures: secrets en código, hashing débil, credenciales hardcodeadas
- A03 Injection: SQL injection, command injection, path traversal, template injection
- A05 Security Misconfiguration: debug mode activo, CORS permisivo sin justificación
- A07 Authentication Failures: tokens sin expiración, almacenamiento inseguro de sesiones
- A09 Logging Failures: datos sensibles (contraseñas, tokens, PII) en logs

En `hardened`: también revisa prompt injection si el código interactúa con LLMs, y nuevas dependencias con CVEs conocidos.

Un BLOCKER de security siempre escala al usuario. No hay auto-retry para problemas de seguridad.

### Adversarial

Activa **únicamente** cuando code-quality y security aprueban por unanimidad. Ese es exactamente el momento de mayor riesgo de falso positivo colectivo.

Asume que existe al menos un fallo. No puede aprobar silenciosamente: si no encuentra nada, explica qué revisó y por qué no encontró problemas.

Busca:
- Off-by-one en comparaciones y rangos
- Race conditions en código concurrente
- Mutación de estado compartido sin sincronización
- Returns silenciosos de None/null en casos de error
- Edge cases sin cubrir: input vacío, input muy grande, acceso concurrente, fallos de red, timeouts
- Asunciones ocultas: orden de elementos, validación upstream, consistencia de APIs externas
- Tests débiles: assertions vacuos, solo happy path, mocks que no reflejan comportamiento real
- Blind spots de integración: qué pasa cuando el servicio externo falla a mitad de una operación

### Smoke-tester (standard + hardened)

Ejecuta cada item del `## Done when` del task.md. Cada PASS requiere evidencia observable (output real del comando, respuesta HTTP, contenido del fichero), no "parece que funciona".

Se adapta al stack del Repo Context:
- REST API: levanta el servidor, ejecuta curl a los endpoints, verifica status y body
- CLI: ejecuta el binario con los argumentos del criterio, verifica exit code y stdout
- Library: script desechable que importa y ejercita la funcionalidad
- Data/ML: ejecuta el pipeline sobre fixtures de `tests/fixtures/`, verifica outputs

Modo sandbox (default): usa fixtures en `tests/fixtures/`, sin llamadas de red reales.
Modo live: usa credenciales de `.env.test`, con APIs reales.

Veredicto: `PASS` (con evidencia por criterio) / `FAIL` (con el criterio específico que falló y el output real).

### Mutation-tester (hardened only)

Solo actúa sobre las funciones marcadas como críticas por el Planner. No analiza todo el código.

Por cada función crítica:
1. Identifica 3-5 mutaciones mínimas: cambio de operador (`>` → `>=`, `+` → `-`), condición eliminada, swap de `and`/`or`, early return eliminado, valor booleano invertido
2. Aplica la mutación al código
3. Ejecuta los tests del módulo
4. Verifica que algún test falla — si todos pasan, el test no detecta el bug introducido
5. Revierte la mutación
6. Calcula el mutation score: mutaciones detectadas / total de mutaciones

Score ≥ 80%: `STRONG`. Score < 80%: `WEAK`.

`WEAK` en función crítica: BLOCKED. `WEAK` en función no crítica: WARNING (acepta si ≥ 60%).

---

## Review: pipeline y gestión de retries

Los reviewers corren en paralelo. El Orchestrator sintetiza y gestiona retries automáticamente:

| Fallo | Acción del Orchestrator | Max retries |
|---|---|---|
| Code bug / tests / types | SendMessage al Coder con contexto del fallo | 2 → escala al usuario |
| Security BLOCKED | SendMessage al Coder | 1 → si es problema de diseño → usuario directo |
| Cleaner no cumple CRAP gate | Cleaner segundo intento | 2 → escala al usuario |
| Smoke FAIL (app no arranca) | SendMessage al Coder | 2 → usuario |
| Smoke FAIL (fixture falta) | Orchestrator añade el fixture | 1 → usuario si no sabe qué fixture crear |
| Mutation WEAK (no crítico) | Coder añade assertions | 1 → acepta con WARNING si ≥ 60% |
| Mutation WEAK (crítico) | Coder añade assertions | 1 → BLOCKED si no mejora |
| Conflicto rebase mecánico | Orchestrator resuelve solo | — |
| Conflicto rebase lógico | Usuario con contexto exacto del conflicto | — |

Un BLOCKED de security nunca tiene auto-retry. Siempre va al usuario.

---

## Checkpoint

Tras el Specifier, el Orchestrator presenta la spec al usuario antes de que empiece cualquier implementación:

```
── Spec lista ──────────────────────────────────────────────────

Tarea:    Añadir exportación de usuarios a CSV
Branch:   feature/add-user-csv-export
Variante: standard

Scope:
  Carpetas: src/users/, tests/unit/users/, tests/integration/
  Fuera de scope: email delivery, formato Excel, paginación

Acceptance criteria:
  ✓ GET /users/export → 200 + CSV con una fila por usuario
  ✓ Sin autenticación → 401
  ✓ CSV incluye: id, email, created_at, role

Plan de alto nivel:
  Crear: src/users/export.py, tests/unit/users/test_export.py
  Modificar: src/users/router.py, src/users/schemas.py

¿Empezamos? [s/n] o describe ajustes →
```

Respuestas posibles:
- **s / enter**: el Planner arranca inmediatamente
- **n**: el Orchestrator limpia el worktree y sale
- **texto libre**: el Specifier recibe el feedback, refina la spec, y el Orchestrator la presenta de nuevo

---

## Gestión del worktree

El Orchestrator gestiona el worktree llamando a scripts. El usuario no interactúa con él directamente.

```
INICIO
  da-worktree.sh create "[descripción de la tarea]"
  → genera slug, determina branch (feature/ o fix/)
  → git worktree add ../[repo]-[slug] -b feature/[slug]
  → devuelve: WORKTREE_PATH, BRANCH
  Coder y Cleaner trabajan exclusivamente en WORKTREE_PATH
  Los reviewers analizan el diff, no trabajan en el worktree

TRAS EL CODER / CLEANER
  da-verify.sh --worktree WORKTREE_PATH
  → ejecuta test, lint, type_check con los comandos del config
  → devuelve: OVERALL=PASS|FAIL, detalle de cada gate
  → si FAIL: SendMessage al Coder con el output de error

PRE-PR
  da-rebase.sh --worktree WORKTREE_PATH
  → git fetch origin && git rebase origin/main
  → devuelve: STATUS=CLEAN|MECHANICAL_RESOLVED|LOGICAL_CONFLICT
  → CLEAN / MECHANICAL_RESOLVED: continúa
  → LOGICAL_CONFLICT: Orchestrator presenta el diff al usuario y espera decisión
  da-verify.sh --worktree WORKTREE_PATH   (verificación final tras rebase)

PR ABIERTO
  da-pr.sh --worktree WORKTREE_PATH --task task.md
  → lee task.md, adapta al PR template del repo si existe
  → gh pr create → devuelve PR_URL
  da-worktree.sh remove WORKTREE_PATH
  → git worktree remove, limpia referencias locales
  → el branch remoto queda hasta que el equipo lo mergee
```

---

## Scripts

Prefijo `da-` (dev-agent). Misma filosofía que `dt-*` en dev-team: encapsulan operaciones mecánicas repetitivas para que el LLM solo lea un output estructurado y tome decisiones, sin gastar tokens en I/O, comandos git o formatting.

Todos los scripts leen `devagent.config.yml` via `da-config.sh` para obtener los comandos configurados. Todos admiten `--dry-run`.

---

### `da-config.sh` — Lectura de configuración

Fusiona `devagent.config.yml` (valores explícitos del equipo) con los valores auto-detectados del Repo Context. Expone la configuración resultante como pares `key=value`.

```bash
da-config.sh                        imprime toda la config fusionada
da-config.sh defaults.variant       → standard
da-config.sh quality.crap_threshold → 15
da-config.sh commands.test          → pytest  (del config o auto-detectado)
```

Todos los demás scripts sourcean `da-config.sh` internamente. El Orchestrator lo llama al inicio de cada sesión para tener la configuración disponible.

---

### `da-worktree.sh` — Ciclo de vida del worktree

```bash
da-worktree.sh create "[descripción de la tarea]"
# Genera slug desde la descripción (lowercase, hyphens, max 50 chars)
# Determina prefijo: feature/ para features, fix/ para bugs
# Ejecuta: git fetch origin && git worktree add ../[repo]-[slug] -b feature/[slug]
# Output:
#   WORKTREE_PATH=../repo-add-user-csv-export
#   BRANCH=feature/add-user-csv-export
#   SLUG=add-user-csv-export
# Falla si el branch ya existe en remote (otra instancia ya lo reclamó)

da-worktree.sh remove ../repo-add-user-csv-export
# git worktree remove [path] --force
# Limpia referencias locales al branch
# El branch remoto no se toca (el equipo decide cuándo borrarlo)

da-worktree.sh list
# Lista worktrees activos con path, branch y fecha de creación
```

---

### `da-verify.sh` — Gate de calidad

Es el script más llamado: después del Coder, después del Cleaner (cada cambio), y antes del PR. Cada llamada sin script cuesta tokens describiendo cómo correr los comandos y parsear el output.

```bash
da-verify.sh [--worktree ../repo-slug]
# Lee comandos de da-config.sh (test, lint, type_check)
# Ejecuta en orden: test → lint → type_check
# Para en el primero que falle
# Output:
#   TEST=PASS|FAIL
#   LINT=PASS|FAIL
#   TYPE=PASS|FAIL
#   OVERALL=PASS|FAIL
#   ERRORS=[output exacto de los comandos que fallaron]
# Sin --worktree: corre en el directorio actual
```

---

### `da-rebase.sh` — Rebase pre-PR con detección de conflictos

Detecta si los conflictos son mecánicos (los resuelve) o de lógica (los reporta sin tocar nada, el Orchestrator escala al usuario).

```bash
da-rebase.sh [--worktree ../repo-slug]
# git fetch origin
# git rebase origin/main
# Analiza conflictos si los hay:
#   Marcadores de conflicto en: whitespace, imports, orden de líneas → resuelve y continúa
#   Marcadores en: lógica de funciones, condiciones, valores → no toca
# Output:
#   STATUS=CLEAN|MECHANICAL_RESOLVED|LOGICAL_CONFLICT
#   CONFLICTS=[lista de ficheros + diff exacto del conflicto, solo si LOGICAL_CONFLICT]
```

El Orchestrator solo lee `STATUS`. Si es `LOGICAL_CONFLICT`, presenta `CONFLICTS` al usuario con el diff exacto y espera instrucciones.

---

### `da-pr.sh` — Creación del PR

Lee `task.md` y genera el PR. Si existe `.github/PULL_REQUEST_TEMPLATE.md` en el repo, adapta el body a ese formato.

```bash
da-pr.sh --worktree ../repo-slug [--dry-run]
# Lee task.md del worktree: título, spec Gherkin, plan, implementation notes, review results
# Lee .github/PULL_REQUEST_TEMPLATE.md si existe
# Genera el body del PR adaptado al template o con formato por defecto
# Ejecuta: gh pr create --title "[título]" --body "[body]"
# Output:
#   PR_URL=https://github.com/org/repo/pull/42
# --dry-run: imprime el comando sin ejecutarlo
```

---

### `da-task.sh` — Gestión de task.md

Crea y actualiza el fichero `task.md` que actúa como estado compartido entre agentes durante la sesión.

```bash
da-task.sh init --variant=standard --branch=feature/add-user-csv-export [--worktree ../repo-slug]
# Crea task.md con frontmatter inicial (variant, status=specifying, branch)

da-task.sh status coding [--worktree ../repo-slug]
# Actualiza el campo status en el frontmatter
# Valores válidos: specifying → planning → coding → cleaning → reviewing → done

da-task.sh get branch [--worktree ../repo-slug]
# Imprime el valor de un campo del frontmatter

da-task.sh append-notes "Decidí usar streaming porque..." [--worktree ../repo-slug]
# Añade una entrada al bloque ## Implementation Notes con timestamp
```

---

### Dónde llama el Orchestrator a cada script

```
INICIO DE SESIÓN
  da-config.sh              → obtiene configuración fusionada

CREACIÓN DEL WORKTREE
  da-worktree.sh create     → worktree + branch

TRAS SPECIFIER
  da-task.sh init           → crea task.md

TRAS APROBACIÓN DEL CHECKPOINT
  da-task.sh status planning

TRAS PLANNER
  da-task.sh status coding

TRAS CODER
  da-verify.sh              → gate calidad
  da-task.sh status reviewing  (si pasa) / permanece en coding (si falla → retry)

TRAS CLEANER (hardened, cada cambio)
  da-verify.sh              → verifica que no rompió nada

PRE-PR
  da-rebase.sh              → rebase + detección de conflictos
  da-verify.sh              → verificación final tras rebase

PR
  da-pr.sh                  → crea PR desde task.md
  da-worktree.sh remove     → destruye worktree
```

---

## Configuración

### `devagent.config.yml` (en el repo del usuario, opcional)

Si no existe, el Scout infiere todo desde los ficheros del proyecto. Si existe, actúa como base y el Scout rellena los campos no definidos.

```yaml
defaults:
  variant: standard            # one-shot | standard | hardened

model:
  reasoning: claude-opus-4-8         # orchestrator, specifier
  implementation: claude-sonnet-4-6  # planner, coder, cleaner, reviewers

quality:
  crap_threshold: 15                 # gate del cleaner (hardened)
  coverage_threshold: 70             # cobertura mínima de tests
  mutation_score_threshold: 80       # score mínimo del mutation-tester (hardened)
  critical_modules: []               # paths donde mutation siempre corre aunque no estén marcadas
  smoke_test_mode: sandbox           # sandbox | live

workflow:
  human_checkpoint: before_code      # before_code | before_pr | both | none
  pr_mode: automatic                 # automatic | manual (imprime el comando para que lo ejecute el usuario)

commands:
  test: ""        # auto-detect desde package.json / pyproject.toml
  lint: ""
  type_check: ""
  run: ""
```

### Flags por invocación (override puntual)

```bash
/agent "add user export"                       usa defaults del config
/agent --variant=hardened "rewrite auth"       override de variante para esta tarea
/agent --no-checkpoint "fix README typo"       salta el checkpoint (one-shot implícito)
/agent --branch=fix/csv-escaping "..."         nombre de branch manual
/one-shot "fix README typo"                    alias para --variant=one-shot
/hardened "rewrite auth middleware"            alias para --variant=hardened
```

---

## PR description

Se genera desde `task.md`. Si existe `.github/PULL_REQUEST_TEMPLATE.md` en el repo, el contenido se adapta a ese formato. Si no:

```markdown
## Qué hace este PR
[descripción de la tarea]

## Acceptance Criteria
```gherkin
[Gherkin del task.md]
```

## Cambios
- `src/users/export.py` — nueva lógica de generación CSV
- `src/users/router.py` — nuevo endpoint GET /users/export
- `src/users/schemas.py` — nuevo schema ExportRow
- `tests/unit/users/test_export.py` — unit tests
- `tests/integration/test_users_export.py` — integration test

## Tests
- Unit: tests/unit/users/test_export.py ✓
- Integration: tests/integration/ ✓
- Smoke: todos los criterios de aceptación pasados ✓

## Notas de implementación
[Implementation Notes del task.md si las hay]

🤖 Generated with dev-agent (standard)
```

---

## Constitution framework

Siguiendo el patrón de SwarmForge: artículos compartidos extensibles sin modificar el fichero base.

```
.claude/constitution/
  engineering.md     funciones <40 líneas, DI, no magic numbers, early returns, sin N+1
  security.md        queries parametrizadas, no secrets en código, no datos sensibles en logs
  testing.md         tests junto al código, sin mocks de red en unit tests, assertions significativas
  handoffs.md        formato de comunicación entre agentes y con el Orchestrator

  local-engineering.md   override del proyecto — extiende sin reemplazar el base
  local-testing.md       override de testing conventions del proyecto
```

Cada agent prompt comienza con: *"Lee todos los ficheros en `.claude/constitution/`. Si existe un fichero `local-*`, sus instrucciones prevalecen sobre el fichero base correspondiente."*

Esto permite que un proyecto con convenciones específicas (por ejemplo, "aquí usamos Vitest en lugar de Jest") sobrescriba solo lo necesario sin tocar los agentes ni los artículos compartidos.

---

## Estructura del repositorio

```
dev-agent/
  README.md
  devagent.config.yml              template de config para copiar al repo del usuario
  .gitignore                       incluye .dev-agent/

  scripts/
    da-config.sh                   lectura de configuración fusionada
    da-worktree.sh                 ciclo de vida del worktree (create / remove / list)
    da-verify.sh                   gate test+lint+type_check
    da-rebase.sh                   rebase pre-PR con detección de conflictos
    da-pr.sh                       creación del PR desde task.md
    da-task.sh                     gestión de task.md (init / status / get / append-notes)
    da-common.sh                   helpers compartidos (sourced, no ejecutable directo)

  .claude/
    agents/
      specifier.md
      planner.md
      coder.md
      cleaner.md
      code-quality.md
      security.md
      adversarial.md
      smoke-tester.md
      mutation-tester.md

    commands/
      agent.md                     /agent — comando principal (standard por defecto)
      one-shot.md                  /one-shot — alias variante rápida
      hardened.md                  /hardened — alias variante máxima
      setup.md                     /setup — genera o regenera .dev-agent/context.md

    constitution/
      engineering.md
      security.md
      testing.md
      handoffs.md

  docs/
    adr/                           decisiones de arquitectura del propio framework

---

En el repo del usuario (generado por /setup o al primera /agent):

  .dev-agent/                      git-ignored — contexto local de la máquina
    context.md                     Repo Context generado por el Scout
```

---

## Referentes y diferencias

### vs SwarmForge (Uncle Bob)

SwarmForge usa tmux + CLI tools reales en sesiones de terminal, con un daemon de handoffs en Babashka y worktrees por rol (no por tarea). dev-agent usa el Claude Agent SDK puro, sin daemon, sin tmux, portable.

Lo que dev-agent toma de SwarmForge:
- Filosofía de variantes (two-pack / four-pack / six-pack → one-shot / standard / hardened)
- Gherkin como formato de spec (más mecánico y verificable que bullets)
- CRAP score como gate cuantitativo antes del review
- Separación entre mejorar (cleaner) y juzgar (reviewers)
- Constitution framework: artículos compartidos + overrides locales sin modificar el base
- Commit bylines por agente (`By coder.`, `By cleaner.`)

### vs dev-team

dev-team gestiona proyectos completos con DAG de tareas, múltiples agentes en paralelo, bootstrapping, y estado persistente entre sesiones. dev-agent es su complemento para trabajo en proyectos ya existentes con equipos.

Lo que dev-agent toma de dev-team:
- Formato de agentes: `.claude/agents/*.md` con frontmatter (model, tools, system prompt)
- Review pipeline: code-quality, security, adversarial son directamente reutilizables
- Git worktrees por tarea para aislamiento
- Checkpoint obligatorio antes de que empiece el código
- Rebase pre-PR con resolución diferenciada (mecánico vs lógico)
- Lógica de retries estructurada por tipo de fallo
