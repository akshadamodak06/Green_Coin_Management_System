# Green-Coin Management System

## Team Members  
- Diya Patel (202301216)  
- Maanav Gurubaxani (202301438)  
- Shubham Varmora (202301450)  
- Yesha Joshi (202301462)  
- Akshada Modak (202301485)  

**Instructor:** Prof. P. M. Jat  
**Institution:** Dhirubhai Ambani University (DAU)  

---

## Project Overview  

The **Green-Coin Management System** is a structured relational database developed to streamline the management of carbon credits under a cap-and-trade policy. It allows **governments to monitor emissions**, **companies to report and trade credits**, and **NGOs/citizens to access data**, fostering a transparent and sustainable environmental ecosystem.

---

## Functional Highlights  

- **Emission Monitoring:** Track greenhouse gas emissions by company and type.  
- **Credit & Penalty Automation:** Allocate credits, calculate penalties, and reward eco-compliance.  
- **Policy Enforcement:** Implement government regulations and conditions dynamically.  
- **Transaction Logging:** Record carbon credit trades between organizations.  
- **Stakeholder Integration:** Support for company branches, POCs, regulators, NGOs, and public access.

---

## Schema Components  

Grouped by functionality, the system includes:

### Company Operations  
`Company`, `CompanyType`, `Branch`, `POCs`, `CompanyEmail`, `POCEmail`, `Project`

### Environmental Data  
`CompanyEmission`, `GreenhouseGases`, `CompanyTypeGasMapping`, `Conditions`, `CompanyConditions`

### Compliance & Credits  
`Regulation`, `GovernmentPolicy`, `Reward`, `Penalty`, `Credit`, `Transaction`, `Regulator`

### NGO & Public Oversight  
`NGOs`, `NGOCollabrations`

---

## Repository Contents  

| File                  | Purpose                                       |
|-----------------------|-----------------------------------------------|
| `ER_Diagram.png`      | Entity-Relationship Diagram                   |
| `Relational_Diagram.png` | Relational schema with keys & constraints |
| `DDL_Script.sql`      | SQL script for schema creation               |
| `Data_Insertion.sql`  | Sample data population                       |
| `Queries.sql`         | SQL queries for insights and analytics       |
| `Triggers.sql`        | Business logic via SQL triggers              |

---

## 🛠Tools & Technologies  

- **SQL**, **Relational Database Design**, **Normalization**, **Entity-Relationship Modeling**  
- Focused on **data integrity**, **auditability**, and **scalability**

---

> A database-driven solution to enable smart, sustainable, and policy-aligned carbon emission management.
