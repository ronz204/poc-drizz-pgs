import { generateId } from "@drizz/database/helpers/column.helper";
import { core } from "@drizz/database/helpers/existing.helper";
import { tenantIsolationPolicy } from "@drizz/database/policies/tenant.policy";
import * as pg from "drizzle-orm/pg-core";
import { tenants } from "./tenant.schema";

export const services = core.table.withRLS(
	"services",
	{
		id: pg.uuid("id").primaryKey().$defaultFn(generateId),
		tenantId: pg
			.uuid("tenant_id")
			.notNull()
			.references(() => tenants.id),
		name: pg.text("name").notNull(),
		createdAt: pg
			.timestamp("created_at", { withTimezone: true })
			.notNull()
			.defaultNow(),
		updatedAt: pg
			.timestamp("updated_at", { withTimezone: true })
			.notNull()
			.defaultNow(),
	},
	(table) => [
		pg.unique("services_tenant_id_id_unique").on(table.tenantId, table.id),
		pg.unique("services_tenant_id_name_unique").on(table.tenantId, table.name),
		tenantIsolationPolicy(table.tenantId),
	],
);
