# Practo Doctor Appointments Database

## 01. Problem Understanding

### 1. Business Context

Practo operates as a digital healthcare platform connecting patients, doctors and clinics through doctor discovery, appointment scheduling, consultations, prescriptions and patient feedback. Its database supports both operational activities—such as finding available doctors, booking appointments and managing clinic check-ins—and analytical activities, including patient safety monitoring, service quality measurement and financial reporting.

The supplied production export contains **599,382 records across 11 datasets**, including 150,000 appointments, 40,000 patients, 3,000 doctors, 30,499 doctor schedules and 97,234 prescriptions. This data represents interconnected healthcare workflows rather than isolated records. Consequently, database performance, relationship integrity and reliable information retrieval are essential to the platform's operation.

The dataset also contains 243,085 prescription items, 30,339 doctor reviews, 3,700 doctor-specialization associations, 1,500 clinics, 10 cities and 15 medical specializations. These records provide the foundation for understanding relationships between patients, healthcare providers, medical services and appointment outcomes.

The appointment records cover the period from **1 January 2025 to 30 June 2026**, offering a historical view of platform activity. They can support analysis of appointment patterns, consultation outcomes, patient behaviour and operational performance. The project brief further anticipates a 20× increase in appointment volume, making scalability an important part of the database design.

The current database was assembled by an earlier team, but its documented schema is unavailable. The reconstruction must therefore rely on the supplied data exports, their relationships and the business requirements defined in the project brief.

The project brief identifies seven business problems that require a structured database assessment.

### 2. Business Problem Analysis

| ID | Business requirement and problem analysis | Primary stakeholders | Classification |
|---|---|---|---|
| **P1 – Doctor Discovery** | Patients must be able to discover verified doctors using specialization, city and language preferences, examine doctor profiles and retrieve available appointment slots efficiently. Generating free slots dynamically from weekly schedules can make the search and booking experience slower. | Patients, Doctors | Customer-facing / Real-time |
| **P2 – Patient Experience** | Patients require prompt access to sign-in, upcoming appointments, appointment history and prescription details. Appointment booking must also respond quickly to avoid delays during the booking process. | Patients, Support Team, Doctors | Customer-facing / Real-time |
| **P3 – Clinic Operations** | Clinic reception teams need immediate access to a doctor's daily appointment queue, including patient details, appointment timings and check-in status. Delayed queue retrieval or check-in updates can disrupt reception workflows and increase patient waiting time. | Clinic Reception, Clinics, Doctors, Patients | Customer-facing / Real-time |
| **P4 – Patient Safety** | The platform must help care teams identify potential medication-allergy conflicts, overdue follow-ups and patterns of patients consulting multiple doctors within the same specialization. These insights support safer and more coordinated patient care. | Patient-Safety Team, Care Team, Patients, Doctors | Reporting / Analytics |
| **P5 – Clinic Partnerships** | The clinic partnerships team needs to identify clinics that have no doctor schedules associated with them. This information supports operational follow-up and helps identify gaps in clinic onboarding and scheduling coverage. | Clinic Partnerships, Clinics | Reporting / Analytics |
| **P6 – Service Quality** | Quality teams need reliable insights into appointment no-shows, consultation waiting times, doctor ratings and potential double bookings. These indicators help evaluate service reliability, identify operational inefficiencies and improve the patient experience. | Quality Team, Clinics, Doctors | Reporting / Analytics |
| **P7 – Business Intelligence and Scalability** | Finance, pharmacy and insights teams require timely reports covering collected consultation fees, prescribed medicines, appointment trends and population-health patterns. The database must also be designed to handle an expected 20× increase in appointment volume without unacceptable performance degradation. | Finance, Pharmacy Partners, Insights Team, Management | Reporting / Analytics |

### 3. Data Evidence and Business Significance

The supplied datasets provide the information needed to investigate the seven business problems:

| Dataset | Records | Business relevance |
|---|---:|---|
| `doctors.csv` | 3,000 | Doctor profiles, verification, experience, fees and languages |
| `doctor_specializations.csv` | 3,700 | Relationships between doctors and medical specializations |
| `doctor_schedules.csv` | 30,499 | Weekly availability, working hours and consultation locations |
| `clinics.csv` | 1,500 | Clinic identity, location and city information |
| `patients.csv` | 40,000 | Patient profiles, contact details, blood groups and allergies |
| `appointments.csv` | 150,000 | Booking history, consultation status, timestamps and payments |
| `prescriptions.csv` | 97,234 | Diagnoses, prescription notes and follow-up dates |
| `prescription_items.csv` | 243,085 | Prescribed medicines, dosage, duration and instructions |
| `doctor_reviews.csv` | 30,339 | Ratings, recommendations and reported waiting-time categories |
| `cities.csv` | 10 | Geographic classification of clinics and patients |
| `specializations.csv` | 15 | Medical specialization reference information |

These datasets are interconnected. For example, an appointment links a patient with a doctor and may also reference a clinic. A prescription is associated with an appointment, while individual medicines are represented separately through prescription items. Doctor reviews are also connected to completed appointment activity.

This structure makes relational integrity important: inaccurate or missing relationships could affect patient history, clinic operations, prescription retrieval and analytical reporting.

### 4. Core Business and Database Requirements

The seven problems establish the following requirements for the rebuilt database:

1. **Efficient information retrieval:** Support doctor discovery, patient records, appointment histories and prescription access through well-defined relationships and appropriate constraints.
2. **Reliable appointment management:** Maintain accurate appointment statuses, scheduling information, consultation types and payment records.
3. **Operational responsiveness:** Support time-sensitive clinic queues, patient check-ins and appointment booking.
4. **Patient safety and continuity:** Preserve patient allergy information, prescription details and follow-up records so that care teams can identify relevant risks and pending actions.
5. **Data integrity:** Maintain valid relationships between patients, doctors, clinics, schedules, appointments, prescriptions and reviews.
6. **Analytical capability:** Enable trustworthy reporting for service quality, financial performance, pharmacy activity and population-health analysis.
7. **Scalability:** Establish a database structure capable of supporting the projected 20× growth in appointment volume.
8. **Consistency of business information:** Ensure that operational screens and analytical reports use reliable, consistent records for appointment status, consultation type, payment and prescription information.
9. **Maintainability:** Establish a clearly documented schema so that future developers and database administrators can understand, extend and maintain the system.
10. **Performance observability:** Use execution plans, query timings and database statistics to identify bottlenecks and evaluate improvements rather than relying on assumptions.

### 5. Query Workload and Performance Assessment

The project defines a workload of **30 SQL queries**, consisting of 25 read operations (R01–R25) and five write operations (W01–W05). These queries represent the practical database operations associated with the seven business problems.

| Problem area | Related workload | Main assessment focus |
|---|---|---|
| P1 – Doctor Discovery | R01, R02, R03, R18 | Doctor search, profiles, schedules and available slots |
| P2 – Patient Experience | R04, R06, R07, W01 | Patient appointments, sign-in, prescriptions and booking |
| P3 – Clinic Operations | R05, W02 | Doctor queue retrieval and patient check-in |
| P4 – Patient Safety | R10, R11, R25, W03 | Allergy-related medicine searches, follow-ups and care patterns |
| P5 – Clinic Partnerships | R13 | Identification of clinics without doctor schedules |
| P6 – Service Quality | R08, R09, R14, R24, W04 | No-shows, waiting time, ratings, double bookings and appointment status updates |
| P7 – Business Intelligence and Scalability | R12, R15, R16, R17, R19, R20, R21, R22, R23, W05 | Financial reporting, pharmacy analysis, population health, platform analytics and operational support |

The workload will provide a common basis for measuring database performance before and after optimization. Each query will be evaluated using the prescribed `EXPLAIN (ANALYZE, BUFFERS)` method, with three executions and an average execution time. The results will help distinguish problems caused by inefficient scans, joins, filtering, sorting or large-volume data processing.

### 6. Assumptions and Scope

- The 11 supplied CSV files are treated as the authoritative source for the initial database reconstruction.
- Existing identifiers are evaluated as candidate primary keys, while relationship tables are assessed for appropriate composite keys.
- Multiple doctor specializations and multiple weekly schedules per doctor are valid business relationships.
- A missing clinic reference may represent a video consultation or a schedule without a physical clinic; its exact meaning must be validated against the corresponding records before defining constraints.
- Optional patient, prescription and consultation fields are retained as nullable only where supported by the source data and business rules.
- Appointment fees are treated as historical transaction values rather than automatically derived from a doctor's current consultation fee.
- Performance classifications are based on business usage: operational screens require responsive access, whereas analytical workloads may process larger volumes of records.
- The expected 20× appointment growth is treated as a scalability requirement specified in the project brief, not as a measured forecast.
- The supplied CSV exports are treated as historical snapshots. Any assumptions about real-time updates, concurrent bookings or future operational behaviour must be evaluated separately.
- Database constraints must preserve all valid source records. Data should not be deleted or modified simply to make the schema load successfully.
- Any data-quality issue discovered during profiling or loading must be documented and distinguished from an incorrect database constraint.
- Performance improvements must preserve the original query results. Changes to query logic, indexing and database structure must be supported by execution evidence.

### 7. Project Objective

The objective is to reconstruct a reliable and well-constrained PostgreSQL database from the supplied production exports, establish a documented understanding of the business workflows, evaluate the performance of the prescribed SQL workload, and apply evidence-based optimization techniques. The final design should preserve data correctness while supporting responsive healthcare operations, meaningful business analytics and future platform growth.

The project will progress from understanding the business requirements and reconstructing the relational schema to loading and validating the source data, measuring baseline query performance, optimizing database operations and evaluating scalability against the projected growth scenario.

Ultimately, the goal is not simply to create tables that accept CSV files. It is to establish a dependable data foundation that supports the healthcare platform's operational needs, protects the integrity of patient-related information and enables informed business decisions as the platform grows.
