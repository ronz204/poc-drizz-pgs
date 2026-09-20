import { generateId } from "@drizz/database/helpers/column.helper";
import { core } from "@drizz/database/helpers/existing.helper";
import { tenantIsolationPolicy } from "@drizz/database/policies/tenant.policy";
import * as pg from "drizzle-orm/pg-core";
import { tenants } from "./tenant.schema";

export const subscribers = core.table.withRLS(
	"subscribers",
	{
		id: pg.uuid("id").primaryKey().$defaultFn(generateId),
		tenantId: pg
			.uuid("tenant_id")
			.notNull()
			.references(() => tenants.id),
		email: pg.text("email").notNull(),
		createdAt: pg
			.timestamp("created_at", { withTimezone: true })
			.notNull()
			.defaultNow(),
	},
	(table) => [
		pg
			.unique("subscribers_tenant_id_email_unique")
			.on(table.tenantId, table.email),
		tenantIsolationPolicy(table.tenantId),
	],
);
