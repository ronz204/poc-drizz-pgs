import * as pg from "drizzle-orm/pg-core";
import { generateId } from "@drizz/database/helpers/column.helper";
import { core } from "@drizz/database/helpers/existing.helper";
import { tenantIsolationPolicy } from "@drizz/database/policies/tenant.policy";
import { tenants } from "./tenant.schema";

export const incidentStatus = core.enum("incident_status", [
  "investigating",
  "identified",
  "monitoring",
  "resolved",
]);

export const incidentSeverity = core.enum("incident_severity", ["minor", "major", "critical"]);

export const incidents = core.table.withRLS("incidents", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull().references(() => tenants.id),
  title: pg.text("title").notNull(),
  status: incidentStatus("status").notNull().default("investigating"),
  severity: incidentSeverity("severity").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: pg.timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.unique("incidents_tenant_id_id_unique").on(table.tenantId, table.id),
  pg.index("incidents_tenant_id_status_idx").on(table.tenantId, table.status),
  pg.index("incidents_tenant_id_created_at_idx").on(table.tenantId, table.createdAt.desc()),
  tenantIsolationPolicy(table.tenantId),
]);
