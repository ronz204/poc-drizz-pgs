import { defineConfig } from "vitest/config";

export default defineConfig({
	resolve: {
		alias: {
			"@tests": "./testing",
			"@app": "./source/capp",
			"@core": "./source/core",
		},
	},
	test: {
		include: ["testing/**/*.test.ts"],
	},
});
