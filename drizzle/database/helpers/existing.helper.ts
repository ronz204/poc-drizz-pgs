import * as pg from "drizzle-orm/pg-core";
export const core = pg.pgSchema("core").existing();

import { pgRole } from "drizzle-orm/pg-core";
export const runner = pgRole("runner").existing();
export const sampler = pgRole("sampler").existing();
