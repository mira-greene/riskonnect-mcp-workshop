// Assign permission set to Platform Integration User
// Usage: sf apex run --file scripts/apex/assign-piu-permset.apex --target-org <alias>

String permSetName = 'Riskonnect_Policy_Agent_Perm_Set';

// Find the Platform Integration User
List<User> piuList = [
    SELECT Id, Name
    FROM User
    WHERE Name = 'Platform Integration User'
    LIMIT 1
];

if (piuList.isEmpty()) {
    System.debug('ERROR=Platform Integration User not found');
    return;
}

User piu = piuList[0];
System.debug('PIU_ID=' + piu.Id);

// Find the permission set
List<PermissionSet> psList = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE Name = :permSetName
    LIMIT 1
];

if (psList.isEmpty()) {
    System.debug('ERROR=Permission set ' + permSetName + ' not found');
    return;
}

PermissionSet ps = psList[0];
System.debug('PERMSET_ID=' + ps.Id);

// Check if already assigned
List<PermissionSetAssignment> existingAssignments = [
    SELECT Id
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :ps.Id
    AND AssigneeId = :piu.Id
];

if (!existingAssignments.isEmpty()) {
    System.debug('PIU_RESULT=ℹ already assigned');
    return;
}

// Assign permission set to PIU
try {
    PermissionSetAssignment psa = new PermissionSetAssignment(
        PermissionSetId = ps.Id,
        AssigneeId = piu.Id
    );
    insert psa;
    System.debug('PIU_RESULT=✔ assigned');
} catch (Exception e) {
    System.debug('ERROR=' + e.getMessage());
}
