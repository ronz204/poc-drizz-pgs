# Forger — Roadmap

Checklist personal de avance. El plan de build "oficial" (pilares técnicos, alcance funcional, criterios de "done") vive en `.claude/docs/approach.md` — este archivo es solo para ir marcando qué está hecho, fase por fase.

---

## Fase 0 — Validación de stack e infraestructura

- [ ] Levantar Postgres primary + réplica en Docker Compose con streaming replication.
- [ ] Confirmar conectividad desde Bun a ambos nodos.
- [ ] Prueba manual: insertar en primary, verificar que aparece en réplica, medir el lag aproximado.

## Fase 1 — Dominio + escritura básica

- [ ] Modelar Tenant, Service, Incident, IncidentUpdate con Hexagonal.
- [ ] Un solo endpoint de escritura (crear incidente), todo contra primary.
- [ ] Sin multi-tenancy todavía — un tenant hardcodeado para simplificar.

## Fase 2 — Multi-tenancy real

- [ ] Implementar aislamiento (RLS y/o filtrado por `tenant_id` — comparar ambos).
- [ ] Autenticación básica que resuelve el tenant actual desde la sesión/token.
- [ ] Verificar el invariante de aislamiento Service↔Incident↔Tenant tanto en dominio como en constraints de DB.

## Fase 3 — Read replica routing

- [ ] Implementar el `ReadIncidentRepository` que pega contra la réplica.
- [ ] Exponer el status page público usando este adapter.
- [ ] Observar el replication lag en carne propia: escribir un incidente y leerlo inmediatamente desde el status page.

## Fase 4 — Resolver el lag (decisión de arquitectura documentada)

- [ ] Elegir una estrategia entre: read-your-writes, consistencia eventual con indicador de staleness, o versionado por timestamp.
- [ ] Implementarla.
- [ ] Documentar la decisión y sus trade-offs en `.claude/docs/structure.md`.

## Fase 5 — Particionamiento + analytics

- [ ] Particionar `IncidentUpdate` por rango de fecha si el volumen simulado lo justifica.
- [ ] Agregar métricas (ej. "uptime % por servicio, por mes") vía materialized views.
- [ ] Practicar `EXPLAIN ANALYZE` comparando antes/después de particionar e indexar.

---

## Fase 6 (stretch) — Failover manual

- [ ] Matar el primary intencionalmente, promover la réplica a primary.
- [ ] Observar qué se rompe en la app (conexión hardcodeada al primary = single point of failure) y por qué.
- [ ] Documentar qué se necesitaría para un failover automático real (fuera de alcance implementarlo).

## Stretch goals adicionales (no ordenados, opcionales)

- [ ] `Subscriber` + notificaciones.
- [ ] PgBouncer delante de ambos nodos, evaluar impacto en connection pooling con RLS activo.
- [ ] Métricas de fair usage: cuánta carga genera cada tenant al primary vs a las réplicas.
