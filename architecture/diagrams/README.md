# Architecture diagrams

Two source formats are provided for all 12 required diagrams:

- **[`../mermaid/`](../mermaid)** — the primary, authoritative source. Renders natively in GitHub (every `.mmd` file is embedded by filename below) and is diffable in pull requests.
- **[`../drawio/`](../drawio)** — editable `.drawio` XML, openable in [diagrams.net](https://app.diagrams.net). These are deliberately simple labeled-box layouts, not AWS-icon diagrams — see the limitation note below.

| # | Diagram | Mermaid | draw.io |
|---|---|---|---|
| 1 | Executive Architecture | [01-executive-architecture.mmd](../mermaid/01-executive-architecture.mmd) | [01-executive-architecture.drawio](../drawio/01-executive-architecture.drawio) |
| 2 | Landing Zone Integration | [02-landing-zone-integration.mmd](../mermaid/02-landing-zone-integration.mmd) | [02-landing-zone-integration.drawio](../drawio/02-landing-zone-integration.drawio) |
| 3 | Event Flow | [03-event-flow.mmd](../mermaid/03-event-flow.mmd) | [03-event-flow.drawio](../drawio/03-event-flow.drawio) |
| 4 | Security Architecture | [04-security-architecture.mmd](../mermaid/04-security-architecture.mmd) | [04-security-architecture.drawio](../drawio/04-security-architecture.drawio) |
| 5 | API Integration | [05-api-integration.mmd](../mermaid/05-api-integration.mmd) | [05-api-integration.drawio](../drawio/05-api-integration.drawio) |
| 6 | EventBridge Architecture | [06-eventbridge-architecture.mmd](../mermaid/06-eventbridge-architecture.mmd) | [06-eventbridge-architecture.drawio](../drawio/06-eventbridge-architecture.drawio) |
| 7 | SQS Processing Architecture | [07-sqs-processing-architecture.mmd](../mermaid/07-sqs-processing-architecture.mmd) | [07-sqs-processing-architecture.drawio](../drawio/07-sqs-processing-architecture.drawio) |
| 8 | DynamoDB Architecture | [08-dynamodb-architecture.mmd](../mermaid/08-dynamodb-architecture.mmd) | [08-dynamodb-architecture.drawio](../drawio/08-dynamodb-architecture.drawio) |
| 9 | Monitoring Architecture | [09-monitoring-architecture.mmd](../mermaid/09-monitoring-architecture.mmd) | [09-monitoring-architecture.drawio](../drawio/09-monitoring-architecture.drawio) |
| 10 | Disaster Recovery | [10-disaster-recovery.mmd](../mermaid/10-disaster-recovery.mmd) | [10-disaster-recovery.drawio](../drawio/10-disaster-recovery.drawio) |
| 11 | AI-Enabled Future Architecture | [11-ai-enabled-future-architecture.mmd](../mermaid/11-ai-enabled-future-architecture.mmd) | [11-ai-enabled-future-architecture.drawio](../drawio/11-ai-enabled-future-architecture.drawio) |
| 12 | Terraform Deployment | [12-terraform-deployment.mmd](../mermaid/12-terraform-deployment.mmd) | [12-terraform-deployment.drawio](../drawio/12-terraform-deployment.drawio) |

## Limitation: official AWS Architecture Icons

This environment has no access to the AWS Architecture Icons asset package or a draw.io rendering/export toolchain, so:
- The Mermaid diagrams use plain labeled shapes, not AWS service icons.
- The `.drawio` files use generic colored boxes, not the AWS icon stencil library.

To finish these with official icons: open each `.drawio` file in [diagrams.net](https://app.diagrams.net), enable the **AWS19 / AWS Architecture** shape library (More Shapes → Networking → AWS), and swap each generic box for the matching service icon — the labels and layout already identify which icon goes where. The free [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/) package is the same asset used by diagrams.net's built-in library.