# Phase 1 — Problem Understanding

Practo connects patients with doctors and clinics for doctor search, appointment booking, consultations, prescriptions and reviews. The undocumented database must be reconstructed from 11 related CSV exports. It must support operational screens and analytical reporting while preserving patient, appointment and prescription relationships. The brief anticipates appointment volume growing 20×.

## Business problems and workload

| ID | Need, affected stakeholders | Class | Queries |
|---|---|---|---|
| P1 — Doctor discovery | Patients need to find verified doctors by specialization, city and language, view profiles and find available slots; doctors need accurate schedules displayed. | Customer-facing / real-time | R01–R03, R18 |
| P2 — Patient experience | Patients and support staff need fast sign-in, appointment history and prescription views; booking must respond promptly. | Customer-facing / real-time | R04, R06, R07, W01 |
| P3 — Clinic operations | Clinic reception needs the doctor's daily queue and check-in status without delay; clinics, doctors and patients depend on an accurate queue. | Customer-facing / real-time | R05, W02 |
| P4 — Patient safety | Patient-safety and care teams need to find allergy risks, overdue follow-ups and patients consulting multiple doctors in one specialty. | Reporting / analytics | R10, R11, R25, W03 |
| P5 — Clinic partnerships | The partnerships team needs to identify clinics with no doctor schedule so onboarding and coverage gaps can be addressed. | Reporting / analytics | R13 |
| P6 — Service quality | Quality teams need reliable no-show, waiting-time, rating and double-booking analysis to improve service for clinics and doctors. | Reporting / analytics | R08, R09, R14, R24, W04 |
| P7 — Business intelligence and growth | Finance, pharmacy partners and insights teams need fee, medicine, appointment and population-health reports; the database must accommodate the stated 20× appointment growth. | Reporting / analytics | R12, R15–R17, R19–R23, W05 |

## Assumptions

- The supplied CSVs are the authoritative starting snapshot; preserve their valid rows and identifiers.
- Multiple specializations and weekly schedules per doctor are valid. A clinic may be absent for a video consultation; confirm nullability against the data before constraining it.
- Appointment fees are historical values and need not equal a doctor's current fee. Optional fields remain nullable only where the source and business rules allow it.
- Operational screens need responsive lookups; reports may process larger row sets. The 20× growth is a brief-specified scenario, not a measured forecast.
- The exports are historical snapshots; concurrency and real-time behavior require separate evidence. Any data-quality issue must be reported rather than hidden by changing source rows.

The project will reconstruct and validate the relational schema, measure the prescribed workload, and evaluate evidence-based optimization and scalability while preserving query correctness.
