import { sql } from "drizzle-orm";
import { pgPolicy } from "drizzle-orm/pg-core";
import { runner } from "@db/schemas/roles.schema";
import type { AnyPgColumn } from "drizzle-orm/pg-core";

export function tenantIsolationPolicy(tenantId: AnyPgColumn) {
  const predicate = sql`${tenantId} = current_setting('app.tenant_id', true)::uuid`;

  return pgPolicy("tenant_isolation", {
    as: "restrictive",
    for: "all",
    to: runner,
    using: predicate,
    withCheck: predicate,
  });
};
