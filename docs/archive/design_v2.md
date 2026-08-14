# dev-team v2 — Diseño del Manager

> Estado: **propuesta de diseño**. Este documento describe el diseño funcional y el
> modelo de control de la versión 2 de dev-team. No incluye plan de implementación.
> Los nombres **Manager** y **`/manage`**, y los valores de configuración, son
> provisionales y ajustables.

---

## 1. TL;DR

dev-team v1 ejecuta tareas de software con un equipo de agentes de IA en paralelo,
pero el **humano no escala**: coordinar 4-5 flujos paralelos obliga a saltar entre
otras tantas conversaciones, cada una esperando una aprobación manual.

dev-team **v2** agrega una capa por encima: el **Manager**, un agente que ocupa el
puesto del humano en la coordinación. El usuario mantiene **un solo chat** con el
Manager. El Manager lanza orquestadores en paralelo, resuelve por sí mismo la mayoría
de las decisiones, escala al humano solo lo genuinamente de diseño/gusto/irreversible,
y mantiene el pipeline lleno lanzando nuevas tareas a medida que otras terminan.

La v2 es **aditiva**: no reescribe la v1. Cada orquestador sigue siendo un
`/orchestrate` de v1 intacto; el Manager es una capa nueva que los lanza y coordina a
través de git y el sistema de archivos.

---

## 2. Contexto: qué es dev-team v1

*(Para quien no conoce el proyecto.)*

dev-team es un framework para construir software con un equipo de agentes de IA
mediante desarrollo paralelo dirigido por especificaciones. **La fuente única de
verdad es git** — no hay servicios externos, bases de datos ni dashboards.

### 2.1 El flujo macro

```
IDEA.md → /bootstrap → design.md + plan.md + tasks/ → /orchestrate → merge → /done
```

1. El usuario describe su idea en `IDEA.md`.
2. `/bootstrap` es una sesión de diseño conversacional que genera la arquitectura
   (`design.md`), el plan de fases (`plan.md`), las tareas (`tasks/`) y los agentes
   especializados del proyecto.
3. `/orchestrate` toma una tarea y la lleva de punta a punta.
4. El usuario mergea el PR en GitHub y corre `/done T-XXX`, que marca la tarea como
   hecha y desbloquea las que dependían de ella.

### 2.2 El ciclo de vida de una tarea

El estado vive en el frontmatter YAML de cada tarea y se refleja moviéndola entre
carpetas:

```
tasks/available/ → in-progress/ → pr-open/ → done/
                                (blocked/, cancelled/ para el resto)
```

Las transiciones se hacen con scripts canónicos (`dt-claim`, `dt-ready`, `dt-done`,
`dt-cancel`, `dt-restart`) que son idempotentes y validan sus entradas. El script
`dt-board` regenera un caché del tablero (`.dt-index.json`, git-ignored).

### 2.3 La coordinación (el mecanismo clave de v1)

- El **estado** de una tarea (los movimientos entre carpetas) se commitea directamente
  a `main`. Por eso `main` **no puede estar protegida**: `tasks/**` es metadata de
  coordinación, no código.
- El **código** de cada tarea vive en su rama `feature/T-XXX-slug` y se desarrolla en
  un **git worktree aislado** (`../proyecto-T-XXX/`).
- El **lock atómico de claim** es crear la rama remota:
  `git push origin main:refs/heads/<branch>`. Si dos sesiones intentan tomar la misma
  tarea, la que pierde la carrera del push nunca toca `main`. Así se garantiza que dos
  sesiones nunca agarran la misma tarea.

### 2.4 `/orchestrate` en 4 fases

Cada sesión de `/orchestrate` es un **orquestador**: un coordinador que delega en
subagentes especializados y es el único que habla con el humano.

| Fase | Subagente | Qué hace |
|------|-----------|----------|
| 1 — Análisis | **architect** | Valida la tarea contra el estado actual del proyecto; protege contratos compartidos; mantiene el DAG acíclico; escribe ADRs. |
| 2 — Planning | **planner** | Convierte la tarea aprobada en un plan concreto a nivel archivo/función. No escribe código. |
| 3 — Coding | **coder** | Implementa el plan solo dentro de sus `folders:`, escribe los tests en el mismo PR, verifica lint/types/coverage. |
| 4 — Review | **code-quality, security, adversarial, smoke-tester, mutation-tester** (en paralelo) | Revisión de calidad completa; el perfil de review escala con el riesgo del diff. |

Un recurso compartido, el **advisor**, está disponible para cualquier subagente ante
trade-offs de diseño reales.

### 2.5 Los puntos donde v1 espera al humano

Dentro de una tarea, el orquestador **para y espera al humano** en:

1. **Post-análisis (Fase 1):** aprobar la definición/scope de la tarea. Es el
   **único checkpoint obligatorio** — no se puede saltar.
2. **Blockers mid-flight:** el coder devuelve un blocker que requiere decisión.
3. **Conflicto de diseño en rebase:** reconciliar código en conflicto tras un merge.
4. **Before-PR (si está configurado):** aprobar el resultado antes de abrir el PR.

Estos cuatro puntos son la clave de la v2: **todos pasan a ir al Manager**.

---

## 3. El problema que resuelve la v2

La paralelización de v1 funciona a nivel de git: podés correr `/orchestrate` en varios
chats a la vez, cada uno en su worktree, sin que dos agarren la misma tarea.

Pero el cuello de botella es el **humano**. Con 5 flujos:

- Tenés 5 conversaciones abiertas, cada una esperando tu checkpoint.
- Hacés *context-switching* constante entre ellas.
- Perdés la visión global del proyecto.
- Cada aprobación (que muchas veces es rutinaria) te bloquea a vos y al flujo.

El valor de v1 —las compuertas de calidad y las aprobaciones humanas— se vuelve su
límite de escala.

---

## 4. Objetivo de la v2: el Manager

Introducir un **meta-orquestador** —el **Manager**— que se sienta *por encima* de los
orquestadores de tarea y ocupe el puesto del humano en la coordinación.

```
Manager (portfolio / donde antes estaba el humano)
   → N Orquestadores (una tarea cada uno)
      → especialistas (architect / planner / coder / reviewers)
```

El humano mantiene **un solo chat**, con el Manager. El Manager:

- **Lanza orquestadores en paralelo** hasta un presupuesto de concurrencia.
- **Interactúa con cada uno** en cada punto donde v1 esperaba al humano.
- **Resuelve por sí mismo** la mayoría de esas interacciones (aprobar planes rutinarios,
  contestar blockers de código, revisar PRs limpios).
- **Escala al humano solo lo genuino** (diseño, gusto, irreversible).
- **Rellena el pipeline**: cuando una tarea termina, lanza la siguiente disponible.
- **Reporta estado** al humano y responde sus consultas y órdenes.

### 4.1 El principio rector: "aceptar lo rutinario, escalar lo consecuente"

El Manager **no** es un sello de goma que acepta todo. Los sistemas multi-agente
producen basura precisamente cuando la auto-aceptación sin revisión se compone tarea
tras tarea. El Manager acepta lo rutinario y escala lo consecuente, según una
**política configurable**. No se elimina el juicio humano: se mueve de *"un checkpoint
en cada tarea"* a *"una política + excepciones"*.

Una elegancia del diseño: el **architect** de v1 ya emite `VALID / ADJUSTED / BLOCKED`
más flags (contratos, protected files, conflictos, discoveries). El Manager casi no
necesita inteligencia nueva para decidir aprobar/escalar: **aplica una política sobre
el output que el architect ya produce**.

### 4.2 El modelo del Manager

- El Manager es un **modelo tope** (provisional: Fable, `claude-fable-5`), un escalón
  por encima de Opus, porque su trabajo es **juicio** (aprobar / escalar / agendar), no
  generación pesada de tokens.
- Los modelos de los procesos hijos (planner, coder, reviewers) **no cambian**: siguen
  los modelos baratos de `model.implementation`. Se paga el modelo caro solo por el
  juicio del Manager, no por generar código.

---

## 5. Arquitectura

### 5.1 Tres capas

```
┌─────────────────────────────────────────────────────────────┐
│  CHAT ÚNICO  =  MANAGER  (sesión Claude, modelo Fable)        │
│  - corre un loop de scheduling                                │
│  - lee estado de archivos, decide, lanza/resume procesos      │
│  - habla solo con el humano                                   │
└───────────────┬───────────────────────────────────────────────┘
                │ lanza vía Bash, procesos independientes:
      ┌─────────┼─────────┬─────────────┐
      ▼         ▼         ▼             ▼
 claude -p   claude -p  claude -p   claude -p     ← cada uno = un /orchestrate v1
 /orch T-003 /orch T-005 /orch T-007 ...            (en modo "managed")
   │            │           │
   └─ architect/planner/coder/reviewers (subagentes propios de cada proceso)

        Bus de comunicación (todos leen/escriben):
        ├─ .dt-flows/T-XXX.json     (git-ignored)  ← latido + estado + parks
        ├─ context/escalations.md   (committeado)  ← escalaciones a humano (auditoría)
        └─ tasks/**  +  .dt-index.json              ← tablero v1 (ya existe)
```

La capa de abajo (orquestador + especialistas) es **v1 intacta**. Lo nuevo es la capa
del Manager y el bus de comunicación.

### 5.2 Por qué `claude -p` y no subagentes anidados

El diseño ingenuo sería: Manager → spawnea orquestadores como **subagentes** → que a su
vez spawnean architect/planner/coder. **No funciona.** En el harness actual, **un
subagente no puede spawnear más subagentes** (deshabilitado por defecto; el opt-in es
por SDK y poco profundo). El orquestador-subagente no podría invocar a sus
especialistas, y perderíamos toda la especialización que hace buena a la v1.

La solución: el Manager lanza cada orquestador como un **proceso `claude -p`
independiente** (vía Bash). Cada proceso:

- tiene su **propio contexto** aislado,
- **conserva su capacidad de spawnear** architect/planner/coder (es un proceso raíz, no
  un subagente),
- es, literalmente, **un `/orchestrate` de v1**.

Consecuencia: la v2 es una **capa nueva encima**, no una refactorización. Paralelismo
real a nivel de sistema operativo.

### 5.3 Git y el sistema de archivos como bus

Dos procesos `claude -p` independientes **no se ven entre sí**: no hay RPC, ni memoria
compartida, ni mensajería directa. La única forma de comunicación es **estado
compartido en el sistema de archivos** — exactamente la filosofía de v1. Esto da algo
**auditable, durable y que sobrevive a que un proceso muera**.

### 5.4 El principio que sostiene todo el control

> **Ningún estado crítico vive solo en la memoria del Manager. Todo está en archivos.**

El Manager es un *loop de control* sobre esos archivos, no una memoria. Por eso, si el
Manager se muere, se relanza y **reconstruye el mundo** leyendo los archivos (ver §7).

---

## 6. Modelo funcional

### 6.1 Cómo se lanza

Un comando nuevo, **`/manage`**, convierte el chat actual en el Manager.

```
/manage                 → arranca con el WIP y la política de devteam.config.yml
/manage --wip 5         → override del presupuesto de concurrencia
/manage --only phase:1  → restringe a un subconjunto de tareas
/manage --dry-run       → planifica y muestra qué lanzaría, sin lanzar
```

**Secuencia de arranque** (primer turno del Manager):

1. Lee `devteam.config.yml`: WIP budget, política de escalación, modelo, autostart.
2. `git fetch && git checkout main && git pull --ff-only` → sincroniza.
3. Corre `dt-board.sh` → regenera `.dt-index.json` (tablero fresco).
4. **Recuperación:** lee `.dt-flows/` → ¿hay flows de una corrida anterior? (ver §7.4).
5. Lee el tablero (disponibles, in-progress, blocked) y `context/escalations.md`
   (escalaciones OPEN).
6. Presenta el plan inicial y pide luz verde una vez (a menos que `autostart: true`):

```
Tablero: 8 disponibles, 0 en progreso, 5 bloqueadas.
Camino crítico: T-003 → T-007 → T-012.
WIP=3. Voy a lanzar en paralelo: T-003, T-005, T-007.
¿Arranco?
```

A partir de ahí, es autónomo: solo vuelve al humano para escalaciones o cuando se le
pregunta.

### 6.2 Ciclo de vida de un flow (un orquestador)

Cada `claude -p "/orchestrate T-003 --managed"` recorre las fases de v1, pero en cada
punto donde v1 **esperaba al humano** (§2.5), ahora **parkea**: escribe qué necesita y
**sale**.

```
Fase 0  claim (dt-claim: crea rama + worktree)   → no parkea
Fase 1  architect analiza                         → PARK: approve_plan
        ── el proceso sale; espera decisión del Manager ──
Fase 2  planner arma el plan                       → (normalmente no parkea)
Fase 3  coder implementa en el worktree            → PARK si blocker de diseño
Fase 4  rebase + reviewers en paralelo             → PARK si conflicto de diseño
                                                   → PARK: before_pr (si configurado)
        abre PR                                     → EXIT (outcome: pr_opened)
```

Entre park y park, el proceso corre **autónomo y completo**, con sus propios
subagentes. Cada tramo entre parks es una **corrida independiente** de `claude -p`.

### 6.3 El bus de comunicación en detalle

#### `.dt-flows/T-XXX.json` — latido + estado por flow (git-ignored)

Un archivo **por flow** (uno por tarea, para que dos flows nunca pisen el mismo archivo
sin locking). Es la vía principal por la que el Manager sigue el estado. El orquestador
lo actualiza en cada transición de fase; el Manager lo lee.

```json
{
  "id": "T-003",
  "session_id": "a1b2c3d4",        // para --resume
  "pid": 48213,                    // para chequear si el proceso vive
  "worktree": "../myproject-T-003",
  "state": "running",              // running | parked | done | failed
  "phase": "coding",               // claim|analysis|planning|coding|review|pr
  "heartbeat": "2026-07-24T10:15:03Z",
  "last_line": "coder: 3/5 archivos, validador de auth listo",
  "started": "2026-07-24T10:02:10Z",
  "pr": null,
  "park": null                     // se llena al parkear (abajo)
}
```

Cuando **parkea**, el orquestador setea `state:"parked"` y llena el bloque `park`:

```json
"state": "parked",
"phase": "analysis",
"park": {
  "type": "approve_plan",          // approve_plan | design_blocker | rebase_conflict | before_pr
  "question": "¿Apruebo el scope del análisis de T-003?",
  "recommendation": "Proceder. VALID, no toca contratos ni protected files.",
  "payload": "## Analysis — T-003\n### Validity: VALID\n...",
  "needs_human_hint": false        // pista del orquestador; el Manager decide igual
}
```

**Importante:** el orquestador siempre parkea *al Manager*, con su **recomendación**
incluida. No decide si algo es "para humano": eso lo decide el Manager (§6.8).

#### `context/escalations.md` — escalaciones al humano (committeado, auditoría)

Solo cuando el Manager decide que un park es para el humano, deja rastro durable acá
(además de decírselo en el chat). Mismo formato open/resolved que `discoveries.md`:

```markdown
## OPEN — 2026-07-24 [Manager → Humano] T-003
Tipo: decisión de diseño
Pregunta: validación en gateway o en service.
Recomendación del Manager: gateway (centraliza, evita duplicar en 3 endpoints).
Flows sin frenar: T-005, T-007 siguen.
Status: open

## RESUELTO — 2026-07-24 [Humano → Manager] T-003
Decisión: gateway. Resumido T-003 con esa dirección.
```

#### Tablero v1 — `tasks/**` + `.dt-index.json`

Ya existe. El estado macro (available → in-progress → pr-open → done) lo siguen
manejando los scripts `dt-*`. El Manager lo usa para saber qué hay disponible y para el
refill.

**Quién escribe qué:**

| Archivo | Escribe | Frecuencia | ¿git? | Para qué |
|---|---|---|---|---|
| `.dt-flows/T-XXX.json` | orquestador | cada fase / park | no | latido + parks |
| `context/escalations.md` | Manager | por escalación a humano | sí | auditoría |
| `tasks/**` frontmatter | scripts `dt-*` | por hito | sí | estado macro |
| `.dt-index.json` | `dt-board` | tras cada `dt-*` | no | tablero agregado |

### 6.4 park-and-resume (el mecanismo exacto)

Es el corazón de la comunicación bidireccional. Secuencia completa (ej: aprobar plan de
T-003):

```
1. Manager lanza (Bash, background):
     claude -p "/orchestrate T-003 --managed" --output-format stream-json
2. El proceso hace Fase 0 (claim) + Fase 1 (architect).
3. En el checkpoint, en vez de "presentar al usuario y esperar", el orquestador:
     a. escribe .dt-flows/T-003.json → state:parked, park:{approve_plan, recomendación, payload}
     b. imprime un JSON final: {"outcome":"parked","flow":"T-003","park":"approve_plan"}
     c. SALE (exit 0)
4. El harness NOTIFICA al Manager que el background task terminó.
5. Manager lee .dt-flows/T-003.json → ve state:parked, type:approve_plan.
6. Manager DECIDE (§6.8):
     - self-resolve (mayoría): "VALID, recomienda proceder → apruebo"
     - o escala al humano: lo postea en el chat + escribe escalations.md
7. Con la decisión, Manager RELANZA:
     claude -p --resume a1b2c3d4 "Decisión del Manager: plan aprobado, procedé con Fase 2."
8. El proceso resumido RETOMA con todo su contexto (historia, plan, worktree)
   exactamente donde estaba, lee la decisión del prompt, y sigue.
```

Dos propiedades clave:

- **La decisión viaja en el prompt del `--resume`.** El orquestador resumido la lee como
  si fuera la respuesta del humano en v1. El archivo queda solo para auditoría.
- **No hay procesos bloqueados quemando tokens.** Un flow parkeado tiene **0 procesos
  vivos** — solo un archivo esperando. El Manager lo revive cuando tiene la respuesta.

### 6.5 El loop del Manager (scheduler)

El Manager actúa por **turnos**. Un turno se dispara por: (a) notificación de que un
proceso terminó, (b) un mensaje del humano, o (c) un timer de respaldo. En cada turno,
tras el RECONCILE (§7.3):

```
── DRENAR ──────────────────────────────────────────────
Para cada proceso que terminó o flow con heartbeat, leer .dt-flows/T-XXX.json:
    outcome=pr_opened → verificar en gh, liberar slot
    state=parked      → va a DECIDIR
    outcome=failed_*  → va a RECUPERACIÓN (§8)
    (sin cambios)     → sigue corriendo; actualizar dashboard interno

── DECIDIR ─────────────────────────────────────────────
Para cada flow parkeado, aplicar la política (§6.8) al park:
    → self-resolve → preparar decisión
    → a humano     → postear en chat + escribir OPEN en escalations.md

── RESUMIR ─────────────────────────────────────────────
Para cada flow con decisión lista (self o respondida por el humano):
    claude -p --resume <session_id> "<decisión>"   (Bash, background)

── REFILL ──────────────────────────────────────────────
mientras (tareas in-progress < WIP) y (hay disponibles+desbloqueadas):
    elegir la mejor (criterio v1: más desbloquea, más chica)
    claude -p "/orchestrate T-YYY --managed"        (Bash, background)

── REPORTAR ────────────────────────────────────────────
Si hay novedades relevantes o escalaciones → digest en el chat.

── DORMIR ──────────────────────────────────────────────
Esperar el próximo evento.
```

### 6.6 Concurrencia — WIP y refill

- **WIP budget** = máximo de tareas *claimed simultáneamente* (in-progress, sin llegar
  a pr-open/done). Controla cuántas ramas/worktrees hay abiertos a la vez → limita la
  superficie de rebase y el costo.
- Un flow parkeado esperando al humano **igual cuenta** en el WIP (la tarea está
  tomada), pero **no consume proceso** (salió). Así "procesos vivos ≤ WIP"
  naturalmente.
- **Refill:** apenas una tarea llega a `pr-open`, se libera un slot y el Manager lanza
  la próxima disponible. Ese es el *"cuando terminan, seguir lanzando"*.
- **Auto-ajuste:** si hay muchas escalaciones sin responder encoladas, el Manager baja
  el ritmo (no lanza más) para no acumular trabajo que depende del humano.

### 6.7 Interacción con el humano

Como todo el estado está en archivos, el Manager responde consultas **leyendo la fuente
de verdad**, no de memoria. Y como sus turnos son baratos (el trabajo pesado está en los
procesos hijos), **está casi siempre disponible para conversar**.

**Pull (el humano pregunta cuando quiere):**

```
estado
  ▶ Corriendo (3/3 WIP): T-005 coding · T-009 review · T-011 analysis
  ⏸ Esperándote (1): T-003 — decisión de validación (gateway/service)
  ✅ PR hoy: T-007  ·  Cola: T-013, T-014, T-016

¿cómo va T-005 en detalle?
  T-005 — coding, fase 3/4. Último latido hace 25s. Sin blockers.

mostrame el plan de T-011
  [lee el plan que produjo el planner y lo muestra]
```

**Steering (el humano dirige):**

```
subí WIP a 5          → lanza más flows si hay disponibles
pausá T-009           → lo saca del scheduling
priorizá pagos        → reordena la cola de refill
dejame tomar T-005    → suelta el flow y deja el worktree al humano
```

**Push (el Manager consulta):** postea en el chat, con **contexto + recomendación + qué
NO se frenó + opciones**. Solo por el chat (no notificaciones al escritorio); el humano
está presente para responder.

**Cuando el humano no está mirando:** el Manager sigue **event-driven** (lo despiertan
las salidas de proceso) + timer de respaldo. El pipeline avanza igual; al volver, el
humano encuentra el digest al día y las escalaciones esperándolo en el chat.

### 6.8 Política de escalación (dos niveles + híbrida)

**Nivel 1:** orquestador → Manager (siempre, en cada park).
**Nivel 2:** Manager → humano (solo lo genuino).

La política es **híbrida**: reglas duras para lo irreversible + criterio en prosa para
la zona gris.

```yaml
manager:
  escalation:
    # HARD RULES — siempre escalan al humano; Fable no las decide
    always_ask:
      - contract_change        # tocar contratos compartidos
      - protected_file         # tocar protected files
      - security_warning       # cualquier warning del security reviewer
      - breaking_change
    # ZONA GRIS — criterio de Fable
    judgment: "Escalá lo que un tech lead senior le consultaría a su manager:
               decisiones de diseño con trade-off real, cosas de gusto/UX,
               o algo irreversible. El resto resolvelo vos."
    # AJUSTES automáticos que no molestan al humano
    auto_ok:
      - valid_no_contracts     # análisis VALID que no toca nada sensible
      - minor_scope_adjust     # ajuste de scope < N archivos
```

Ejemplo self-resolve (el humano no se entera):

```
[interno] T-005 parkeó approve_plan. Análisis VALID, no toca contratos.
          → política auto_ok → Manager resume T-005 "aprobado, procedé".
```

Ejemplo escala al humano:

```
🔶 Decisión — T-003
El coder necesita definir dónde valida el input: gateway o service.
Recomiendo gateway (centraliza, evita duplicar en 3 endpoints).
El resto sigue: T-005, T-009, T-011 corriendo.
¿Gateway, service, u otra cosa?
```

---

## 7. Modelo de control

Esta sección es la que garantiza que **todo esté controlado** y que **nada quede a
medias**. La idea central: el Manager **nunca confía en su memoria**; en cada turno
corre primero un **RECONCILE** que re-deriva el mundo desde git + archivos + procesos
vivos, detecta inconsistencias y las repara *antes* de decidir nada.

### 7.1 Invariantes (lo que el Manager garantiza siempre)

Se chequean en cada RECONCILE. Si alguno se viola, es un incidente a reparar, no a
ignorar.

1. **Toda tarea está en exactamente un estado conocido.** No hay tareas "flotando".
2. **Toda tarea in-progress tiene: rama en origin + worktree + `.dt-flows/T-XXX.json`.**
   Si falta uno → estado a medias → reconciliar.
3. **Todo proceso vivo corresponde a una tarea in-progress.** Proceso huérfano →
   matar/adoptar.
4. **Todo park tiene una decisión pendiente o resuelta — nunca ignorado.**
5. **WIP real (tareas claimed) ≤ WIP budget.** Nunca se sobrepasa.
6. **git es la verdad macro; `.dt-flows` la verdad micro; stdout solo evento.** Ante
   conflicto, gana git.

### 7.2 Máquina de estados de un flow

Cada flow está siempre en **uno** de estos estados.

```
                 dt-claim OK
   [LAUNCHING] ───────────────► [RUNNING] ──park──► [PARKED]
       │  (transient, Mgr)          │   ▲              │
       │  claim falló               │   │ --resume     │ Mgr decide
       ▼                            │   └──[RESUMING]◄──┤
   (descartar, elegir otra)         │      (transient) │
                                    │                  ▼ (si es para el humano)
                       abre PR      │           [AWAITING_HUMAN]
                                    ▼                  │ el humano responde
                               [PR_OPEN] ◄─────────────┘ (vuelve a RESUMING)
                                    │  /done (humano + merge)
                                    ▼
                                 [DONE]

   Desde cualquier estado activo, ante fallo:
        ─────────────────► [FAILED] ──(recuperación §8)──► RESUMING | ABANDONED
   Orden del humano de soltar:
        ─────────────────► [ABANDONED]  (worktree queda al humano / o dt-cancel)
```

| Estado | Quién lo setea | Proceso vivo | Slot WIP | Terminal |
|---|---|---|---|---|
| LAUNCHING | Manager | arrancando | sí | no (transient) |
| RUNNING | orquestador (heartbeat) | **sí** | sí | no |
| PARKED | orquestador (al salir) | **no** | sí | no |
| AWAITING_HUMAN | Manager | no | sí | no |
| RESUMING | Manager | arrancando | sí | no (transient) |
| PR_OPEN | orquestador / reconcile | no | **libera** | sí (para el Mgr) |
| FAILED | Manager (detección) | no | sí→repara | no |
| ABANDONED | Manager | no | libera | sí |
| DONE | humano vía `/done` | no | — | sí |

Los estados *transient* (LAUNCHING, RESUMING) tienen **timeout corto** (ej. 60s). Si no
confirman transición, el Manager reintenta o los pasa a FAILED. Nunca se cuelgan.

### 7.3 RECONCILE — cómo el Manager "ve estados" y repara

Corre **al inicio de cada turno**, antes de decidir.

```
Paso A — Observar la realidad:
  - git: qué hay en tasks/{in-progress,pr-open,done}, qué ramas en origin
  - gh:  qué PRs existen y su estado (open/merged/closed)   ← verdad de PR
  - fs:  qué worktrees existen (git worktree list)
  - .dt-flows/*.json: estado declarado de cada flow
  - procesos: ¿el pid de cada flow sigue vivo?

Paso B — Cruzar y detectar discrepancias (matriz §7.4).
Paso C — Reparar cada discrepancia con su procedimiento.
Paso D — Recién ahora: DRENAR → DECIDIR → RESUMIR → REFILL.
```

Así, aunque el Manager se haya muerto y reiniciado, o un flow haya crasheado en el peor
momento, el turno siguiente **detecta y repara** antes de seguir.

### 7.4 La matriz de "cosas a medias"

Cada combinación anómala que RECONCILE puede encontrar, con su reparación:

| Situación detectada | Diagnóstico | Reparación |
|---|---|---|
| in-progress · pid muerto · sin `park`/`done` · heartbeat viejo | Crasheó en un tramo | `--resume` (1 intento); si no, reintentar tramo; si no, escalar |
| in-progress · rama en origin · **PR existe en gh** · flow no `done` | Abrió PR y murió antes de registrar | Mover a pr-open, `pr:` = URL, liberar slot |
| in-progress · **sin rama** en origin | Claim a medias | Limpiar worktree si quedó, revertir a available, reintentar claim |
| Worktree existe · sin rama / sin flow file | Worktree huérfano | `git worktree remove`, limpiar |
| Rama en origin · **sin** tarea in-progress (quedó available) | Push del claim ganó pero el commit de status no | Completar: mover a in-progress, crear flow file, adoptar |
| `RESUMING` hace > timeout · sigue `parked` en disco | El `--resume` no prendió | Reintentar resume; si no, FAILED → recuperación |
| `PARKED` hace > SLA · nadie decidió | Se perdió una decisión (bug del Manager) | Re-evaluar el park ahora; alertar en digest |
| PR en gh **merged** · tarea aún en pr-open | Se mergeó sin correr `/done` | Ofrecer correr `/done T-XXX` (o hacerlo si autoproceed) |
| PR en gh **closed** sin merge | Se rechazó el PR | Escalar: ¿reabro, cancelo o rehago? |
| 2 flows tocando los mismos `folders:` | Riesgo de conflicto | Serializar (pausar el segundo) + avisar |

Esta matriz es la que garantiza que **nada quede huérfano**: para cada forma de "a
medias" hay una salida definida a un estado conocido.

### 7.5 Contrato de salida de cada proceso (feedback de agentes)

Cuando un `claude -p` termina, **obligatoriamente** deja un `outcome` legible por
máquina en `.dt-flows/T-XXX.json` y como línea final JSON en stdout. Set cerrado:

| outcome | Significado | Reacción del Manager |
|---|---|---|
| `parked` | Llegó a un punto de decisión | Evaluar el park (§7.6) |
| `pr_opened` | Fase 4 completa, PR abierto | Verificar en `gh`, liberar slot, refill |
| `failed_verify` | Tests/lint/type fallaron y el coder no pudo | Retry con feedback / escalar (§8) |
| `failed_blocker` | Blocker que el orquestador no resolvió | Clasificar y proceder (§7.6, §8) |
| `failed_crash` | Excepción/panic del proceso | Recuperación (§8) |
| `aborted` | Se auto-abortó (ej. dt-claim perdió la carrera) | Descartar tarea, elegir otra |
| *(sin outcome)* | Proceso murió sin escribir nada | El caso peligroso → RECONCILE (§7.3-7.4) |

### 7.6 Cómo evalúa el Manager el feedback (parks)

Cada park trae `type + payload + recommendation`. Tabla de decisión:

| park.type | Qué evalúa | Self-resolve si… | Escala al humano si… |
|---|---|---|---|
| `approve_plan` | El análisis del architect (VALID/ADJUSTED/BLOCKED, contratos, protected files) | VALID, no toca contratos/protected, ajuste ≤ umbral | ADJUSTED grande, toca contrato/protected, o BLOCKED |
| `design_blocker` | Opciones A/B del coder + recomendación | Elección técnica sin trade-off de negocio | Trade-off de diseño/gusto/negocio real |
| `rebase_conflict` | Conflicto mecánico vs. de diseño | Mecánico (whitespace, imports) | De diseño (contrato, lógica, schema) — **siempre al humano** |
| `before_pr` | Veredictos de los reviewers + criterios de aceptación | Todo clean, criterios PASS | Cualquier hard-rule (§6.8) o warning de security |

**Evaluación de un resultado de review (Fase 4):**

| Veredicto reviewers | Decisión |
|---|---|
| Todos CLEAN | Aprobar PR |
| WARNING (no security) | Abrir PR con warning flaggeado en el body; avisar en digest |
| WARNING de security | **Hard rule → escala al humano**, no abre |
| BLOCKER | No abre → retry al coder vía resume (§8), con budget |

### 7.7 Timeouts, watchdog y circuit breaker

- **Timeouts por tamaño** (config `timeout_s/m/l`): si un flow supera su tiempo sin
  latido nuevo → watchdog → tratar como `failed_crash` (§8).
- **Latido viejo con pid vivo:** el proceso trabaja un tramo largo (ej. coder). No es
  error si el pid vive y no superó el timeout — solo warning informativo.
- **Circuit breaker:** si N flows fallan seguidos (provisional: 3), el Manager **frena
  el refill** y avisa: *"3 tareas fallaron seguidas — algo sistémico (¿main roto? ¿CI?
  ¿config?). Paro de lanzar hasta que me digas."* Evita quemar presupuesto multiplicando
  un fallo.
- **Techo de escalaciones:** si hay > K escalaciones sin responder, no lanza más.

### 7.8 Contrato de comunicación (campos obligatorios)

Para que no haya ambigüedad, los mensajes tienen **campos requeridos**. Un mensaje
inválido no se adivina: se trata como `failed`.

- **Park record (orquestador → Manager):** `id, session_id, type, phase, question,
  recommendation, payload` — todos obligatorios.
- **Escalación (Manager → humano):** siempre `qué decidir + recomendación + qué NO se
  frenó + opciones`.
- **Decisión (Manager → orquestador, vía prompt de --resume):** `decisión explícita +
  "procedé con Fase N"`.

### 7.9 Semántica de control (órdenes del humano)

Cada orden tiene semántica definida e **idempotente** (repetirla no rompe):

| Orden | Semántica | Si choca con algo en vuelo |
|---|---|---|
| `estado` / `¿cómo va T-X?` | RECONCILE + reporta | — |
| `pausá T-X` | No se resume ni relanza | Si corre un proceso: pregunta abortar o dejar terminar el tramo |
| `subí/bajá WIP a N` | Cambia budget | Si N < actual: no mata flows, deja de refillar |
| `priorizá X` | Reordena cola de refill | — |
| `tomá vos T-X` | Suelta el flow, deja worktree; estado ABANDONED | Si corre: pregunta antes |
| `no toques Y` | Excluye Y del refill | Si un flow ya toca Y: **pregunta** abortar/terminar |
| `pará todo` | Detiene refill; flows vivos terminan su tramo y parkean | — |

---

## 8. Manejo de errores (procedimientos cerrados)

Cada clase de error tiene un **procedimiento**, un **budget** y una **acción al
agotarse**. Nunca "no sé qué hacer": siempre termina en un estado conocido.

```
failed_verify (tests/lint/type):
   → RESUMING con el error específico "arreglá esto: <stderr>"   [budget 2]
   → agotado: escala al humano con el detalle de los 2 intentos

failed_blocker:
   → clasificar (abajo) → resume con dirección   [budget por tipo]
   → agotado: escala con estructura (qué se intentó y por qué no alcanzó)

failed_crash / sin outcome:
   → RECONCILE: el worktree y la rama viven → intentar --resume 1 vez
   → si el resume no arranca: reintentar tramo desde el heartbeat
   → agotado: escala "T-XXX se colgó, ¿/restart o lo tomás vos?"

aborted (perdió el claim):
   → descartar el flow, NO tocar main, elegir otra tarea (regla v1)
```

**Clasificación de blockers y budget de retry** (idéntico a v1, ahora automatizado por
el Manager; el `max_blocker_retries` global de la config es el techo):

| Blocker | Actor | Retries | Agotado |
|---|---|---|---|
| Bug / tipo / test / assert | coder (resume) | 2 | escala al humano |
| Security | coder (resume) | 1 | escala al humano |
| Violación de arquitectura | coder tras architect | 1 | escala al humano |
| Smoke: app no arranca | coder (resume) | 2 | escala al humano |
| Smoke: fixture/env faltante | Manager arregla directo | 1 | escala al humano |
| Conflicto de diseño en rebase | humano | 0 | inmediato |
| Cambio de contrato | architect + humano | 0 | inmediato |

**Reglas duras:** el Manager **nunca abre un PR con un BLOCKER sin resolver**, y
**nunca marca done algo sin PR verificado en `gh`**.

---

## 9. Configuración nueva

Un bloque `manager:` en `devteam.config.yml`:

```yaml
manager:
  model: claude-fable-5      # modelo tope para el juicio del Manager
  wip: 3                     # tareas claimed en paralelo
  autostart: true            # lanza el primer batch sin pedir confirmación
  digest_every: 5m           # cada cuánto da un resumen proactivo (o solo on-demand)
  circuit_breaker: 3         # fallos seguidos antes de frenar el refill
  max_pending_escalations: 5 # techo de escalaciones sin responder antes de frenar
  escalation:                # ver §6.8
    always_ask: [contract_change, protected_file, security_warning, breaking_change]
    judgment: "..."
    auto_ok: [valid_no_contracts, minor_scope_adjust]
```

Los modelos de los procesos hijos (planner, coder, reviewers) **no cambian**: siguen
`model.implementation`.

---

## 10. Cambios necesarios sobre la v1

La v2 es aditiva; los cambios son acotados:

1. **Modo `--managed` en `/orchestrate`** (`orchestrate.md`): el único cambio de fondo.
   Cada punto que hoy dice *"presentá al usuario y esperá confirmación"* pasa a
   *"escribí el park record + recomendación, salí con un outcome legible por máquina, y
   al resumir leé la decisión inyectada en el prompt"*. En **todos** los puntos de
   interacción (§2.5), no solo el checkpoint. Sin `--managed`, `/orchestrate` se comporta
   como v1 (checkpoint humano).
2. **Comando nuevo `/manage`** y **agente `manager.md`** (modelo Fable): el loop de
   scheduling, RECONCILE, evaluación, escalación y control.
3. **Schema `.dt-flows/T-XXX.json`** y su directorio git-ignored (nuevo primitivo de
   estado micro).
4. **`context/escalations.md`** (nuevo, formato open/resolved como las entradas de `context/discoveries/T-XXX.md`).
5. **Bloque `manager:`** en `devteam.config.yml`.
6. Posibles helpers en `scripts/` para leer/escribir flow records y latidos de forma
   consistente (análogo a `dt-common.sh`).

Lo que **no** cambia: los especialistas (architect, planner, coder, reviewers, advisor),
los scripts `dt-*`, los worktrees, el modelo de ramas y todo el flujo hasta la creación
de tareas (`/bootstrap`, `plan.md`, `design.md`).

---

## 11. Restricciones del harness que moldearon el diseño

- **Los subagentes no pueden spawnear más subagentes** (deshabilitado por defecto). Por
  eso los orquestadores son procesos `claude -p` independientes, no subagentes (§5.2).
- **`claude -p`** corre Claude Code no-interactivo y termina devolviendo un resultado;
  con `--output-format stream-json` se pueden leer eventos en vivo.
- **`--resume <session_id>`** reanuda una sesión (incluidas las de `-p`) con toda su
  historia; la decisión del Manager viaja como prompt de reanudación.
- **Notificaciones de background task:** el harness avisa al Manager cuando un proceso
  hijo termina → el Manager es event-driven, con polling solo para el dashboard.
- **Sin mensajería directa entre sesiones:** la coordinación es por sistema de archivos
  / git (§5.3). Existe una feature experimental (*Agent Teams*) conceptualmente parecida,
  pero está deshabilitada por defecto, no soporta anidamiento ni resume de sesión, y no
  se apoya en este diseño.

---

## 12. Preguntas abiertas

- **Valores exactos de la política de escalación** (`always_ask`, umbrales de
  `minor_scope_adjust`, SLA de decisiones parkeadas). Los defaults de §6.8/§9 son un
  punto de partida.
- **Política fina del circuit breaker** y del techo de escalaciones.
- **Serialización de flows que comparten `folders:`**: ¿pausar el segundo siempre, o
  permitir solapamiento y resolver en rebase?
- **Granularidad del latido** durante tramos largos del coder (hoy es a nivel de fase).
- **Nombres definitivos** de `Manager` y `/manage`.
```
