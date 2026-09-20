import type { Tenant } from "../tenant/tenant.aggregate";
import { TenantId } from "../tenant/tenant.vos";
import { DuplicateServiceNameError } from "./service.errors";
import type { ServiceSnapshot } from "./service.types";
import { ServiceId } from "./service.vos";

export class Service {
	private constructor(
		readonly id: ServiceId,
		readonly tenantId: TenantId,
		readonly name: string,
	) {}

	public static create(
		tenant: Tenant,
		name: string,
		existingServiceNames: readonly string[],
	): Service {
		if (existingServiceNames.includes(name)) {
			throw new DuplicateServiceNameError(tenant.id.value, name);
		}
		return new Service(ServiceId.generate(), tenant.id, name);
	}

	public static reconstitute(snapshot: ServiceSnapshot): Service {
		return new Service(
			ServiceId.from(snapshot.id),
			TenantId.from(snapshot.tenantId),
			snapshot.name,
		);
	}
}
