// Seed demo Policy_Gap__c records
// Usage: sf apex run --file data/seed-gaps.apex --target-org <alias>

// Query the policy documents we just created
Map<String, Policy_Document__c> policyMap = new Map<String, Policy_Document__c>();
for (Policy_Document__c pol : [SELECT Id, Policy_ID__c FROM Policy_Document__c WHERE Policy_ID__c IN ('POL-001', 'POL-002', 'POL-004')]) {
    policyMap.put(pol.Policy_ID__c, pol);
}

if (policyMap.isEmpty()) {
    System.debug('ERROR: No policies found. Run seed-policies.apex first.');
    return;
}

List<Policy_Gap__c> gaps = new List<Policy_Gap__c>();

// Gap 1: GDPR Article 30 - Data Privacy Policy
if (policyMap.containsKey('POL-001')) {
    gaps.add(new Policy_Gap__c(
        Policy_Document__c = policyMap.get('POL-001').Id,
        Regulation_Name__c = 'GDPR',
        Regulation_Article__c = 'Article 30',
        Gap_Description__c = 'Current policy does not specify record of processing activities (ROPA) maintenance requirements. GDPR Article 30 mandates that controllers maintain records of all processing activities under their responsibility.',
        Recommended_Action__c = 'Add section: "The organization shall maintain a comprehensive record of all personal data processing activities, including purposes, categories of data subjects and personal data, recipients, data retention periods, and security measures, as required by GDPR Article 30."',
        Severity__c = 'High',
        Status__c = 'Open',
        Identified_Date__c = Date.today().addDays(-5),
        Target_Resolution_Date__c = Date.today().addDays(30)
    ));
}

// Gap 2: SEC Cyber Rules - Incident Response Policy
if (policyMap.containsKey('POL-002')) {
    gaps.add(new Policy_Gap__c(
        Policy_Document__c = policyMap.get('POL-002').Id,
        Regulation_Name__c = 'SEC Cybersecurity Rules',
        Regulation_Article__c = 'Form 8-K Item 1.05',
        Gap_Description__c = 'Policy lacks 4-business-day incident disclosure timeline mandated by SEC. Current policy references generic "timely notification" but does not specify the 4-day Form 8-K filing requirement for material cybersecurity incidents.',
        Recommended_Action__c = 'Add section: "Material cybersecurity incidents must be disclosed on Form 8-K within four business days of determining materiality, per SEC Regulation S-K Item 1.05. The Incident Response Team will assess materiality in consultation with Legal and escalate to the Board for disclosure determination."',
        Severity__c = 'Critical',
        Status__c = 'Open',
        Identified_Date__c = Date.today().addDays(-2),
        Target_Resolution_Date__c = Date.today().addDays(14)
    ));
}

// Gap 3: NIST CSF - Cybersecurity Policy
if (policyMap.containsKey('POL-004')) {
    gaps.add(new Policy_Gap__c(
        Policy_Document__c = policyMap.get('POL-004').Id,
        Regulation_Name__c = 'NIST Cybersecurity Framework',
        Regulation_Article__c = 'PR.AC-4',
        Gap_Description__c = 'Policy does not address access permissions management aligned with NIST CSF. NIST CSF PR.AC-4 requires access permissions and authorizations to be managed, incorporating principles of least privilege and separation of duties.',
        Recommended_Action__c = 'Add section: "Access control policies shall implement least privilege and separation of duties principles. All user access rights shall be reviewed quarterly. Privileged access shall be monitored and logged. Role-based access control (RBAC) shall be enforced across all critical systems per NIST CSF PR.AC-4."',
        Severity__c = 'Medium',
        Status__c = 'Open',
        Identified_Date__c = Date.today().addDays(-10),
        Target_Resolution_Date__c = Date.today().addDays(45)
    ));
}

try {
    insert gaps;
    System.debug('SUCCESS: Created ' + gaps.size() + ' Policy_Gap__c records');
    for (Policy_Gap__c gap : gaps) {
        System.debug('  - ' + gap.Regulation_Name__c + ' ' + gap.Regulation_Article__c + ' (' + gap.Severity__c + ')');
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
