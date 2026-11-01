# Validation

`validate-event-platform.sh <env>` runs read-only smoke checks against the deployed resources: the EventBridge bus, the three DynamoDB tables, the orders queue and its DLQ, the api-handler and orders-worker Lambdas, and the CloudWatch dashboard. It does not check optional, environment-gated resources (custom domain, Managed Grafana, AI integration) — those are verified manually per `docs/deployment-guide.md` when enabled.

Run after every apply:
```bash
bash validation/validate-event-platform.sh dev
```

For plan-time safety, `scripts/plan-guard.sh` is run in CI against every plan before it can be applied — see [`../scripts`](../scripts).
