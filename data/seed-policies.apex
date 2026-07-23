// Seed demo Policy_Document__c records
// Usage: sf apex run --file data/seed-policies.apex --target-org <alias>

List<Policy_Document__c> policies = new List<Policy_Document__c>{
    new Policy_Document__c(
        Name = 'Data Privacy Policy',
        Policy_ID__c = 'POL-001',
        Policy_Category__c = 'Data Privacy',
        Policy_Owner__c = 'Jane Chen, Chief Privacy Officer',
        Last_Review_Date__c = Date.newInstance(2024, 3, 15),
        Status__c = 'Active'
    ),
    new Policy_Document__c(
        Name = 'Incident Response Policy',
        Policy_ID__c = 'POL-002',
        Policy_Category__c = 'Incident Response',
        Policy_Owner__c = 'Mark Rodriguez, CISO',
        Last_Review_Date__c = Date.newInstance(2024, 6, 1),
        Status__c = 'Active'
    ),
    new Policy_Document__c(
        Name = 'Third-Party Risk Management Policy',
        Policy_ID__c = 'POL-003',
        Policy_Category__c = 'Third-Party Risk',
        Policy_Owner__c = 'Sarah Kim, VP Risk Management',
        Last_Review_Date__c = Date.newInstance(2023, 11, 20),
        Status__c = 'Under Review'
    ),
    new Policy_Document__c(
        Name = 'Cybersecurity Policy',
        Policy_ID__c = 'POL-004',
        Policy_Category__c = 'Cybersecurity',
        Policy_Owner__c = 'Mark Rodriguez, CISO',
        Last_Review_Date__c = Date.newInstance(2024, 1, 10),
        Status__c = 'Active'
    ),
    new Policy_Document__c(
        Name = 'Business Continuity Policy',
        Policy_ID__c = 'POL-005',
        Policy_Category__c = 'Compliance',
        Policy_Owner__c = 'David Thompson, Chief Risk Officer',
        Last_Review_Date__c = Date.newInstance(2024, 4, 5),
        Status__c = 'Active'
    )
};

try {
    insert policies;
    System.debug('SUCCESS: Created ' + policies.size() + ' Policy_Document__c records');
    for (Policy_Document__c pol : policies) {
        System.debug('  - ' + pol.Policy_ID__c + ': ' + pol.Name);
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
