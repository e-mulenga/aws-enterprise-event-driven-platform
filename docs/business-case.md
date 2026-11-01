# Business Case

## Executive Summary
ShopSphere Global's order-management platform is a tightly-coupled monolith: order placement, inventory, payments, customer notifications and partner integrations call each other directly. A single slow dependency (a partner API, a notification provider) backs up the whole checkout path, every new integration requires a code change and a full redeploy, and there is no visibility into where an order actually is in its lifecycle short of reading application logs. This repository implements the migration target: an event-driven platform where services communicate through durable, replayable events instead of direct calls, built entirely on managed AWS services inside the existing AWS Enterprise Landing Zone.

## Business Problem Statement
| Problem | Current state | Cost to the business |
|---|---|---|
| Tight coupling | Order service calls inventory, payment, and notification services synchronously | A single dependency outage takes down checkout |
| Scaling limitations | The monolith scales as one unit | Over-provisioned for steady traffic, under-provisioned for flash sales |
| Failure propagation | No isolation between components | One bug can cascade into a platform-wide incident |
| Slow integration development | Every new partner integration is a code change to the monolith | Weeks, not days, to onboard a partner |
| Limited event visibility | No central record of what happened, when | Support and engineering reconstruct incidents from scattered logs |
| Increasing operational costs | Always-on compute sized for peak, not average, load | Compute spend doesn't track actual demand |

## Benefits Analysis
| Capability this platform adds | Business benefit |
|---|---|
| EventBridge custom bus + schema-aware routing | New consumers subscribe to existing events without touching the producer |
| SQS queues with DLQs | A failing downstream service degrades gracefully instead of cascading |
| Lambda, pay-per-invocation | Compute cost tracks actual order volume, not a fixed fleet |
| EventBridge Archive + Replay | Operations can replay a time window of events after fixing a bug, rather than losing data |
| DynamoDB Streams + Event Metadata table | Every domain event is auditable after the fact |
| Multi-Region DR (Global Tables + S3 CRR) | 99.95% availability / 15-minute RTO / 5-minute RPO targets, not best-effort |
| Built entirely on the existing Landing Zone | No duplicate VPC, logging, DNS, OIDC or AI-governance spend — see [landing-zone-dependency-matrix.md](landing-zone-dependency-matrix.md) |

## Portfolio note
This is a demonstration architecture, not ShopSphere Global's actual production system — the company and its pain points are illustrative, used to ground otherwise-abstract architecture decisions in a concrete scenario. Every AWS resource it defines is real and deployable.
