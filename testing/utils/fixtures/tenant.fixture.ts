import { Tenant, type TenantPlan } from "@core/multitenant-org";

export function buildTenant(plan: TenantPlan = "free", slug = "acme"): Tenant {
	return Tenant.create(slug, plan);
}
