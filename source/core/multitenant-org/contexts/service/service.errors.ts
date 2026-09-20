export class DuplicateServiceNameError extends Error {
	constructor(
		readonly tenantId: string,
		readonly serviceName: string,
		cause?: unknown,
	) {
		super(`Tenant "${tenantId}" already has a service named "${serviceName}"`, {
			cause,
		});
		this.name = "DuplicateServiceNameError";
	}
}
