// Mock data for the Riskonnect Policy Advisor MCP server.
//
// This intentionally mirrors data/seed-policies.apex and data/seed-gaps.apex so
// the MCP tool responses and the on-platform Policy_Document__c / Policy_Gap__c
// records tell the SAME story during the workshop. If you change a policy owner,
// a gap article, or a severity here, change it in the seed scripts too.

export const POLICIES = {
  "POL-001": {
    policy_id: "POL-001",
    policy_name: "Data Privacy Policy",
    category: "Data Privacy",
    owner: "Jane Chen, Chief Privacy Officer",
    last_review_date: "2024-03-15",
    status: "Active",
    content_summary:
      "Governs the collection, processing, storage, and disposal of personal data. Covers lawful basis for processing, data subject rights (access, rectification, erasure), consent management, and cross-border transfer safeguards. Does not currently specify record-of-processing-activities (ROPA) maintenance or a formal data-retention schedule.",
  },
  "POL-002": {
    policy_id: "POL-002",
    policy_name: "Incident Response Policy",
    category: "Incident Response",
    owner: "Mark Rodriguez, CISO",
    last_review_date: "2024-06-01",
    status: "Active",
    content_summary:
      "Defines the lifecycle for detecting, triaging, containing, and recovering from security incidents. Establishes the Incident Response Team, severity tiers, and internal escalation paths. References generic 'timely notification' of stakeholders but does not define a regulatory disclosure timeline or materiality assessment process.",
  },
  "POL-003": {
    policy_id: "POL-003",
    policy_name: "Third-Party Risk Management Policy",
    category: "Third-Party Risk",
    owner: "Sarah Kim, VP Risk Management",
    last_review_date: "2023-11-20",
    status: "Under Review",
    content_summary:
      "Establishes due-diligence and ongoing-monitoring requirements for vendors and service providers. Covers risk tiering of suppliers, contractual security clauses, and periodic reassessment. Predates recent supply-chain and data-processor accountability requirements and is currently under review.",
  },
  "POL-004": {
    policy_id: "POL-004",
    policy_name: "Cybersecurity Policy",
    category: "Cybersecurity",
    owner: "Mark Rodriguez, CISO",
    last_review_date: "2024-01-10",
    status: "Active",
    content_summary:
      "Sets baseline technical and administrative safeguards: network security, endpoint protection, vulnerability management, and encryption standards. Addresses access control at a high level but does not codify least-privilege, separation-of-duties, or a quarterly access-review cadence.",
  },
  "POL-005": {
    policy_id: "POL-005",
    policy_name: "Business Continuity Policy",
    category: "Compliance",
    owner: "David Thompson, Chief Risk Officer",
    last_review_date: "2024-04-05",
    status: "Active",
    content_summary:
      "Describes business-impact analysis, recovery-time objectives, and disaster-recovery procedures for critical business functions. Covers backup and failover but does not tie financial-reporting continuity controls to internal-control-over-financial-reporting (ICFR) requirements.",
  },
};

// Canonical regulation names. Aliases (what a user might actually type) map to
// these keys so "SEC Cyber Rules" and "SEC Cybersecurity Rules" resolve the same.
export const REGULATION_ALIASES = {
  gdpr: "GDPR",
  ccpa: "CCPA",
  "sec cyber rules": "SEC Cybersecurity Rules",
  "sec cybersecurity rules": "SEC Cybersecurity Rules",
  sec: "SEC Cybersecurity Rules",
  "nist csf": "NIST Cybersecurity Framework",
  "nist cybersecurity framework": "NIST Cybersecurity Framework",
  nist: "NIST Cybersecurity Framework",
  sox: "SOX",
  "sarbanes-oxley": "SOX",
};

export function normalizeRegulation(name) {
  if (!name) return null;
  return REGULATION_ALIASES[String(name).trim().toLowerCase()] || null;
}

// Gap analysis keyed by "POL-###|Canonical Regulation Name".
// POL-001|GDPR, POL-002|SEC, POL-004|NIST mirror seed-gaps.apex exactly.
export const GAP_ANALYSIS = {
  "POL-001|GDPR": {
    overall_compliance: "Partially Compliant",
    compliance_score: 68,
    gaps: [
      {
        article: "Article 30",
        severity: "High",
        description:
          "Current policy does not specify record of processing activities (ROPA) maintenance requirements.",
        requirement:
          "GDPR Article 30 requires controllers to maintain records of all processing activities under their responsibility, including purposes, categories of data subjects and personal data, recipients, retention periods, and security measures.",
      },
      {
        article: "Article 33",
        severity: "Medium",
        description:
          "Policy does not define the 72-hour breach-notification obligation to the supervisory authority.",
        requirement:
          "GDPR Article 33 requires notification of a personal data breach to the supervisory authority within 72 hours of becoming aware of it, where feasible.",
      },
    ],
  },
  "POL-001|CCPA": {
    overall_compliance: "Partially Compliant",
    compliance_score: 74,
    gaps: [
      {
        article: "§1798.135",
        severity: "Medium",
        description:
          "Policy lacks a clear mechanism for consumers to opt out of the sale or sharing of personal information.",
        requirement:
          "CCPA §1798.135 requires businesses to provide a clear and conspicuous 'Do Not Sell or Share My Personal Information' method and to honor opt-out requests.",
      },
    ],
  },
  "POL-002|SEC Cybersecurity Rules": {
    overall_compliance: "Non-Compliant",
    compliance_score: 45,
    gaps: [
      {
        article: "Form 8-K Item 1.05",
        severity: "Critical",
        description:
          "Policy lacks the 4-business-day incident disclosure timeline mandated by the SEC. It references generic 'timely notification' but does not specify the Form 8-K filing requirement for material cybersecurity incidents.",
        requirement:
          "SEC Regulation S-K Item 1.05 requires disclosure of material cybersecurity incidents on Form 8-K within four business days of determining materiality.",
      },
      {
        article: "Regulation S-K Item 106",
        severity: "High",
        description:
          "Policy does not require periodic disclosure of cybersecurity risk-management processes and governance.",
        requirement:
          "Item 106 requires registrants to describe their processes for assessing, identifying, and managing material cybersecurity risks, and board/management oversight, in annual filings.",
      },
    ],
  },
  "POL-004|NIST Cybersecurity Framework": {
    overall_compliance: "Partially Compliant",
    compliance_score: 71,
    gaps: [
      {
        article: "PR.AC-4",
        severity: "Medium",
        description:
          "Policy does not address access-permissions management aligned with NIST CSF, including least privilege and separation of duties.",
        requirement:
          "NIST CSF PR.AC-4 requires access permissions and authorizations to be managed, incorporating the principles of least privilege and separation of duties.",
      },
    ],
  },
  "POL-005|SOX": {
    overall_compliance: "Partially Compliant",
    compliance_score: 66,
    gaps: [
      {
        article: "Section 404",
        severity: "High",
        description:
          "Business continuity controls are not linked to internal control over financial reporting (ICFR).",
        requirement:
          "SOX Section 404 requires management to establish and assess the effectiveness of internal controls over financial reporting, including the availability and integrity of systems supporting financial reporting.",
      },
    ],
  },
};

// Update recommendations keyed the same way. policy_language mirrors the
// Recommended_Action__c text in seed-gaps.apex for the three seeded combos.
export const UPDATE_RECOMMENDATIONS = {
  "POL-001|GDPR": [
    {
      article: "Article 30",
      priority: "High",
      policy_language:
        'The organization shall maintain a comprehensive record of all personal data processing activities, including purposes, categories of data subjects and personal data, recipients, data retention periods, and security measures, as required by GDPR Article 30.',
      rationale:
        "Closes the Article 30 ROPA gap by mandating a documented, auditable record of processing activities.",
      implementation_notes:
        "Assign the DPO as ROPA owner; review the record at least annually and after any material change in processing.",
    },
    {
      article: "Article 33",
      priority: "Medium",
      policy_language:
        "Upon becoming aware of a personal data breach, the organization shall notify the relevant supervisory authority without undue delay and, where feasible, within 72 hours, unless the breach is unlikely to result in a risk to the rights and freedoms of data subjects.",
      rationale:
        "Establishes the 72-hour notification clock required by GDPR Article 33.",
      implementation_notes:
        "Integrate the 72-hour trigger into the Incident Response Policy escalation workflow.",
    },
  ],
  "POL-001|CCPA": [
    {
      article: "§1798.135",
      priority: "Medium",
      policy_language:
        'The organization shall provide a clear and conspicuous "Do Not Sell or Share My Personal Information" link and shall honor verified consumer opt-out requests within 15 business days.',
      rationale:
        "Provides the opt-out mechanism CCPA §1798.135 requires.",
      implementation_notes:
        "Coordinate with Web/Digital to place the link in the site footer and privacy page.",
    },
  ],
  "POL-002|SEC Cybersecurity Rules": [
    {
      article: "Form 8-K Item 1.05",
      priority: "Critical",
      policy_language:
        "Material cybersecurity incidents must be disclosed on Form 8-K within four business days of determining materiality, per SEC Regulation S-K Item 1.05. The Incident Response Team will assess materiality in consultation with Legal and escalate to the Board for the disclosure determination.",
      rationale:
        "Directly closes the Item 1.05 disclosure-timeline gap and assigns accountability for the materiality decision.",
      implementation_notes:
        "Add a materiality-assessment checklist and a documented Legal/Board escalation path with named roles.",
    },
    {
      article: "Regulation S-K Item 106",
      priority: "High",
      policy_language:
        "The organization shall document its processes for assessing, identifying, and managing material cybersecurity risks, and shall describe board and management oversight of those risks in its annual report.",
      rationale:
        "Satisfies the Item 106 governance-disclosure requirement.",
      implementation_notes:
        "Coordinate annually with Legal and Investor Relations ahead of the 10-K filing.",
    },
  ],
  "POL-004|NIST Cybersecurity Framework": [
    {
      article: "PR.AC-4",
      priority: "Medium",
      policy_language:
        "Access control policies shall implement least-privilege and separation-of-duties principles. All user access rights shall be reviewed quarterly. Privileged access shall be monitored and logged. Role-based access control (RBAC) shall be enforced across all critical systems, per NIST CSF PR.AC-4.",
      rationale:
        "Codifies least privilege, separation of duties, and a quarterly review cadence to close the PR.AC-4 gap.",
      implementation_notes:
        "Stand up a quarterly access-certification campaign; enable privileged-access logging in the SIEM.",
    },
  ],
  "POL-005|SOX": [
    {
      article: "Section 404",
      priority: "High",
      policy_language:
        "Recovery-time and recovery-point objectives for systems supporting financial reporting shall be defined, tested annually, and mapped to internal controls over financial reporting (ICFR). Continuity-control failures affecting financial systems shall be reported to the Disclosure Committee.",
      rationale:
        "Links business-continuity controls to ICFR as required by SOX Section 404.",
      implementation_notes:
        "Map financial-reporting systems to BC/DR runbooks; include ICFR-relevant systems in the annual 404 assessment.",
    },
  ],
};
