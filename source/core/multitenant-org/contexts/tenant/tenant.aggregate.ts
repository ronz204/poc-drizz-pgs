import type { TenantPlan } from "./tenant.enums";
import {
	PlanDowngradeConflictError,
	ServiceCapExceededError,
} from "./tenant.errors";
import type { TenantSnapshot } from "./tenant.types";
import { TenantId } from "./tenant.vos";

const PLAN_SERVICE_CAP: Record<TenantPlan, number> = {
	free: 3,
	pro: 15,
	enterprise: 50,
};

export class Tenant {
	private constructor(
		readonly id: TenantId,
		readonly slug: string,
		readonly plan: TenantPlan,
		readonly serviceCap: number,
	) {}

	public static create(slug: string, plan: TenantPlan): Tenant {
		return new Tenant(TenantId.generate(), slug, plan, PLAN_SERVICE_CAP[plan]);
	}

	public static reconstitute(snapshot: TenantSnapshot): Tenant {
		return new Tenant(
			TenantId.from(snapshot.id),
			snapshot.slug,
			snapshot.plan,
			snapshot.serviceCap,
		);
	}

	public assertCanRegisterService(currentServiceCount: number): void {
		if (currentServiceCount >= this.serviceCap) {
			throw new ServiceCapExceededError(this.id.value, this.serviceCap);
		}
	}

	public changePlan(newPlan: TenantPlan, currentServiceCount: number): Tenant {
		const newServiceCap = PLAN_SERVICE_CAP[newPlan];
		if (currentServiceCount > newServiceCap) {
			throw new PlanDowngradeConflictError(
				this.id.value,
				newServiceCap,
				currentServiceCount,
			);
		}
		return new Tenant(this.id, this.slug, newPlan, newServiceCap);
	}
}
