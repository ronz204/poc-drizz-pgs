import type { TenantPlan } from "./tenant.enums";

export interface TenantSnapshot {
	readonly id: string;
	readonly slug: string;
	readonly plan: TenantPlan;
	readonly serviceCap: number;
}
