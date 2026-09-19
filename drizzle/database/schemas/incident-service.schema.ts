import * as pg from "drizzle-orm/pg-core";
import { core } from "@drizz/database/helpers/existing.helper";
import { tenantIsolationPolicy } from "@drizz/database/policies/tenant.policy";
import { incidents } from "./incident.schema";
import { services } from "./service.schema";

export const incidentServices = core.table.withRLS("incident_services", {
  tenantId: pg.uuid("tenant_id").notNull(),
  incidentId: pg.uuid("incident_id").notNull(),
  serviceId: pg.uuid("service_id").notNull(),
}, (table) => [
  pg.primaryKey({ columns: [table.incidentId, table.serviceId] }),
  pg.foreignKey({
    name: "incident_services_tenant_id_incident_id_fk",
    columns: [table.tenantId, table.incidentId],
    foreignColumns: [incidents.tenantId, incidents.id],
  }),
  pg.foreignKey({
    name: "incident_services_tenant_id_service_id_fk",
    columns: [table.tenantId, table.serviceId],
    foreignColumns: [services.tenantId, services.id],
  }),
  pg.index("incident_services_service_id_tenant_id_idx").on(table.serviceId, table.tenantId),
  tenantIsolationPolicy(table.tenantId),
]);
