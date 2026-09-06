import { sql } from "drizzle-orm";
import * as pg from "drizzle-orm/pg-core";
import { generateId } from "@db/helpers/column.helper";

export const auth = pg.pgSchema("auth").existing();

export const tenantPlanEnum = auth.enum("tenant_plan", ["free", "pro", "enterprise"]);

export const tenants = auth.table("tenants", {
  id: pg.uuid("id").primaryKey().$defaultFn(generateId),
  slug: pg.text("slug").notNull().unique(),
  name: pg.text("name").notNull(),
  plan: tenantPlanEnum("plan").notNull(),
  maxServices: pg.integer("max_services").notNull(),
  createdAt: pg.timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: pg.timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, (table) => [pg.check("tenants_max_services_positive", sql`${table.maxServices} > 0`)]);
