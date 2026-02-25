module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/test"],
  testMatch: ["**/*.spec.ts", "**/*.test.ts"],
  transform: {
    "^.+\\.ts$": "ts-jest",
  },
  globalSetup: "./jest-setup.js",
  moduleNameMapper: {
    "^@test/(.*)$": "<rootDir>/test/$1",
    "^@scripts/(.*)$": "<rootDir>/scripts/$1",
  },
};