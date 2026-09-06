import * as pg from "drizzle-orm/pg-core";
import { generateId } from "@db/helpers/column.helper";
import { tenantIsolationPolicy } from "@db/policies/tenant.policy";
import { tenants } from "@db/schemas/auth.schema";

export const core = pg.pgSchema("core").existing();

export const incidentStatusEnum = core.enum("incident_status", [
  "investigating",
  "identified",
  "monitoring",
  "resolved",
]);

export const incidentSeverityEnum = core.enum("incident_severity", [
  "minor",
  "major",
  "critical"
]);

export const services = core.table.withRLS("services", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull().references(() => tenants.id),
  name: pg.text("name").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: pg.timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.unique("services_tenant_id_id_unique").on(table.tenantId, table.id),
  pg.unique("services_tenant_id_name_unique").on(table.tenantId, table.name),
  tenantIsolationPolicy(table.tenantId),
]);

export const incidents = core.table.withRLS("incidents", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull().references(() => tenants.id),
  title: pg.text("title").notNull(),
  status: incidentStatusEnum("status").notNull().default("investigating"),
  severity: incidentSeverityEnum("severity").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: pg.timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.unique("incidents_tenant_id_id_unique").on(table.tenantId, table.id),
  pg.index("incidents_tenant_status_idx").on(table.tenantId, table.status),
  pg.index("incidents_tenant_created_idx").on(table.tenantId, table.createdAt.desc()),
  tenantIsolationPolicy(table.tenantId),
]);

export const incidentServices = core.table.withRLS("incident_services", {
  tenantId: pg.uuid("tenant_id").notNull(),
  incidentId: pg.uuid("incident_id").notNull(),
  serviceId: pg.uuid("service_id").notNull(),
}, (table) => [
  pg.primaryKey({ columns: [table.incidentId, table.serviceId] }),
  pg.foreignKey({
    columns: [table.tenantId, table.incidentId],
    foreignColumns: [incidents.tenantId, incidents.id],
  }),
  pg.foreignKey({
    columns: [table.tenantId, table.serviceId],
    foreignColumns: [services.tenantId, services.id],
  }),
  pg.index("incident_services_service_tenant_idx").on(table.serviceId, table.tenantId),
  tenantIsolationPolicy(table.tenantId),
]);

export const incidentUpdates = core.table.withRLS("incident_updates", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull(),
  incidentId: pg.uuid("incident_id").notNull(),
  status: incidentStatusEnum("status").notNull(),
  message: pg.text("message").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.foreignKey({
    columns: [table.tenantId, table.incidentId],
    foreignColumns: [incidents.tenantId, incidents.id],
  }),
  pg.index("incident_updates_incident_created_idx").on(table.incidentId, table.createdAt),
  tenantIsolationPolicy(table.tenantId),
]);

export const subscribers = core.table.withRLS("subscribers", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  tenantId: pg.uuid("tenant_id").notNull().references(() => tenants.id),
  email: pg.text("email").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.unique("subscribers_tenant_id_email_unique").on(table.tenantId, table.email),
  tenantIsolationPolicy(table.tenantId),
]);
