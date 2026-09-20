import { sql } from "drizzle-orm";
import * as pg from "drizzle-orm/pg-core";
import { generateId } from "@drizz/database/helpers/column.helper";
import { core } from "@drizz/database/helpers/existing.helper";

export const tenantPlan = core.enum("tenant_plan", ["free", "pro", "enterprise"]);

export const tenants = core.table("tenants", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  slug: pg.text("slug").notNull().unique(),
  name: pg.text("name").notNull(),
  plan: tenantPlan("plan").notNull(),
  maxServices: pg.integer("max_services").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: pg.timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [
  pg.check("max_services_positive", sql`${table.maxServices} > 0`),
]);
