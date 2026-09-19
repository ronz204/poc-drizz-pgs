import * as pg from "drizzle-orm/pg-core";
import { generateId } from "@drizz/database/helpers/column.helper";
import { core } from "@drizz/database/helpers/existing.helper";
import { tenantIsolationPolicy } from "@drizz/database/policies/tenant.policy";
import { incidentStatus, incidents } from "./incident.schema";

export const incidentUpdates = core.table.withRLS("incident_updates", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull(),
  incidentId: pg.uuid("incident_id").notNull(),
  status: incidentStatus("status").notNull(),
  message: pg.text("message").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.foreignKey({
    name: "incident_updates_tenant_id_incident_id_fk",
    columns: [table.tenantId, table.incidentId],
    foreignColumns: [incidents.tenantId, incidents.id],
  }),
  pg.index("incident_updates_incident_id_created_at_idx").on(table.incidentId, table.createdAt),
  tenantIsolationPolicy(table.tenantId),
]);
