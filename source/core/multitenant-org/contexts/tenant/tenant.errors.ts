export class ServiceCapExceededError extends Error {
	constructor(
		readonly tenantId: string,
		readonly serviceCap: number,
		cause?: unknown,
	) {
		super(`Tenant "${tenantId}" reached its service cap of ${serviceCap}`, {
			cause,
		});
		this.name = "ServiceCapExceededError";
	}
}

export class PlanDowngradeConflictError extends Error {
	constructor(
		readonly tenantId: string,
		readonly newServiceCap: number,
		readonly currentServiceCount: number,
		cause?: unknown,
	) {
		super(
			`Tenant "${tenantId}" cannot downgrade to a cap of ${newServiceCap} services because it already has ${currentServiceCount} registered`,
			{ cause },
		);
		this.name = "PlanDowngradeConflictError";
	}
}
