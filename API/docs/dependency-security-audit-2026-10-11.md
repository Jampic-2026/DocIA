# Dependency security correction — 2026-10-11

## Finding and correction

The initial `npm audit --json` reported 20 moderate findings, zero high and zero critical findings. These were propagated findings from one advisory affecting `sprintf-js`, reached through Jest → Istanbul → `@istanbuljs/load-nyc-config` → `js-yaml` 3 → `argparse` 1 → `sprintf-js`.

Advisory: [GHSA-hp3w-g68c-fv3c](https://github.com/advisories/GHSA-hp3w-g68c-fv3c). The advisory lists no patched version of `sprintf-js`; installing its latest version would not resolve the finding.

`package.json` now scopes a `js-yaml: ^4.3.2` override to `@istanbuljs/load-nyc-config`. Its installed implementation calls `load`, which exists in YAML 4; it does not call the removed `safeLoad` API. The regenerated lockfile removes the vulnerable YAML 3 / argparse 1 / sprintf-js chain and refreshes affected test-tool dependencies within the declared ranges. Existing Fastify and gaxios overrides are retained. No advisories are suppressed and no audit exclusions were introduced.

## Executed verification

| Check | Result |
| --- | --- |
| `npm audit --json` | Exit 0; zero findings at all severities, including development dependencies. |
| `npm audit --omit=dev --json` | Exit 0; zero findings in production dependencies. |
| `npm ls js-yaml sprintf-js` | Exit 0; Istanbul resolves js-yaml 4.3.2; sprintf-js absent. |
| `node node_modules/typescript/bin/tsc --noEmit --incremental false` | Exit 0; no type errors. |
| `node node_modules/jest/bin/jest.js --runInBand` | Exit 0; 15 suites and 44 tests passed. |
| YAML compatibility smoke check | Passed: actual Istanbul loader read a temporary `.nycrc.yaml`, inherited another YAML file, normalized `check-coverage`, and retained include/exclude arrays. Temporary fixtures contained synthetic configuration only and were removed. |

Results describe the local dependency tree and npm advisory database queried for this correction. Zero audit findings does not certify absence of vulnerabilities in application logic, infrastructure or future advisories. No production deployment, database operation or real external-provider transaction was performed.
