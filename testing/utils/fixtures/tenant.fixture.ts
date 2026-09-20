import { Tenant } from "@core/multitenant-org/contexts/tenant/tenant.aggregate";
import type { TenantPlan } from "@core/multitenant-org/contexts/tenant/tenant.enums";

export function buildTenant(plan: TenantPlan = "free", slug = "acme"): Tenant {
	return Tenant.create(slug, plan);
}
