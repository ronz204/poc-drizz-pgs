import { uuidv7 } from "uuidv7";

export const INVALID_UUID = "not-a-uuid";

export function validUuid(): string {
	return uuidv7();
}
