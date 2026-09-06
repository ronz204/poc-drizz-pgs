import { pgRole } from "drizzle-orm/pg-core";
export const sampler = pgRole("sampler").existing();
export const runner = pgRole("runner").existing();