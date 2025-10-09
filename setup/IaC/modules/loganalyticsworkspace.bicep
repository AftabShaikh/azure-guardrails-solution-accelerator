param subscriptionId string
param rg string
param logAnalyticsWorkspaceName  string
param location  string
param releaseVersion  string
param releaseDate string
param deployLAW bool
param GRDocsBaseUrl string
param newDeployment bool = true
param updateWorkbook bool = false
var wb = loadTextContent('gr.workbook')
var wbConfig2='"/subscriptions/${subscriptionId}/resourceGroups/${rg}/providers/Microsoft.OperationalInsights/workspaces/${logAnalyticsWorkspaceName}"]}'
//var wbConfig3='''
//'''
// var wbConfig='${wbConfig1}${wbConfig2}${wbConfig3}'
var wbConfig='${wb}${wbConfig2}'

resource guardrailsLogAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: {
    releaseVersion:releaseVersion
    releasedate: releaseDate
  }
  properties: {
    retentionInDays:90
    sku: {
      name: 'PerGB2018'
    }
  }
}
resource f2 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_data'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_data'
    query: '''
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s
    | project Locale_s
    | take 1
);
let itsgcodes=GRITSGControls_CL | summarize arg_max(TimeGenerated, *) by itsgcode_s;
GuardrailsCompliance_CL
| where ControlName_s has ctrlprefix and ReportTime_s == ReportTime and Required_s != tostring(showNonRequired)
| where TimeGenerated > ago (24h)
|join kind=inner (itsgcodes) on itsgcode_s
| project 
    [case(locale == "fr-CA", "Nom de l'élément", "Item Name")]=strcat(ItemName_s, iff(Required_s=="False"," (R)", " (M)")), 
    [case(locale == "fr-CA", "Commentaires", "Comments")]=Comments_s, 
    [case(locale == "fr-CA", "État", "Status")]=case(ComplianceStatus_b == true, '✔️', ComplianceStatus_b == false, '❌', '➖'),
    [case(locale == "fr-CA", "Contrôle ITSG", "ITSG Control")]=itsgcode_s, 
    [case(locale == "fr-CA", "Remédiation", "Remediation")]=gr_geturl(replace_string(ctrlprefix," ",""),itsgcode_s), 
    Profile=iff(isnotempty(column_ifexists("Profile_d", "")), tostring(toint(column_ifexists("Profile_d", ""))), "")
'''
    functionAlias: 'gr_data'
    functionParameters: 'ctrlprefix:string, ReportTime:string, showNonRequired:string'
    version: 3
  }
}
resource f1 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_geturl'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_geturl'
    //query: 'let baseurl="${GRDocsBaseUrl}";\nlet Link=strcat(baseurl,control,"-", replace_string(replace_string(itsgcode,"(","-"),")",""),".md");\nLink\n'
    query: 'let baseurl="${GRDocsBaseUrl}";\nlet Link=baseurl;\nLink\n'
    functionAlias: 'gr_geturl'
    functionParameters: 'control:string, itsgcode:string'
    version: 2
  }
}
resource f3 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_data567'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_data567'
    query: '''
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s
    | project Locale_s
    | take 1
);
let itsgcodes=GRITSGControls_CL | summarize arg_max(TimeGenerated, *) by itsgcode_s;
GuardrailsCompliance_CL
| where ControlName_s has ctrlprefix and ReportTime_s == ReportTime and Required_s != tostring(showNonRequired)
| where TimeGenerated > ago (24h)
|join kind=inner (itsgcodes) on itsgcode_s
| project 
    [case(locale == "fr-CA", "Nom de l'élément", "Item Name")]=strcat(ItemName_s, iff(Required_s=="False"," (R)", " (M)")), 
    [case(locale == "fr-CA", "Nom de l'abonnement", "Subscription Name")]=DisplayName_s, 
    [case(locale == "fr-CA", "Commentaires", "Comments")]=Comments_s, 
    [case(locale == "fr-CA", "État", "Status")]=case(ComplianceStatus_b == true, '✔️', ComplianceStatus_b == false, '❌', '➖'),
    [case(locale == "fr-CA", "Contrôle ITSG", "ITSG Control")]=itsgcode_s, 
    [case(locale == "fr-CA", "Remédiation", "Remediation")]=gr_geturl(replace_string(ctrlprefix," ",""),itsgcode_s), 
    Profile=iff(isnotempty(column_ifexists("Profile_d", "")), tostring(toint(column_ifexists("Profile_d", ""))), "")
'''
    functionAlias: 'gr_data567'
    functionParameters: 'ctrlprefix:string, ReportTime:string, showNonRequired:string'
    version: 3
  }
}
resource f4 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_data11'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_data11'
    query: '''
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s
    | project Locale_s
    | take 1
);
let itsgcodes=GRITSGControls_CL | summarize arg_max(TimeGenerated, *) by itsgcode_s;
GuardrailsCompliance_CL
| where ControlName_s has ctrlprefix and ReportTime_s == ReportTime and Required_s != tostring(showNonRequired)
| where TimeGenerated > ago (24h)
|join kind=inner (itsgcodes) on itsgcode_s
| project 
    [case(locale == "fr-CA", "Nom de l'élément", "Item Name")]=strcat(ItemName_s, iff(Required_s=="False"," (R)", " (M)")), 
    [case(locale == "fr-CA", "Nom de l'abonnement", "Subscription Name")] = SubscriptionName_s, 
    [case(locale == "fr-CA", "Commentaires", "Comments")]=Comments_s, 
    [case(locale == "fr-CA", "État", "Status")]=case(ComplianceStatus_b == true, '✔️', ComplianceStatus_b == false, '❌', '➖'),
    [case(locale == "fr-CA", "Contrôle ITSG", "ITSG Control")]=itsgcode_s, 
    [case(locale == "fr-CA", "Remédiation", "Remediation")]=gr_geturl(replace_string(ctrlprefix," ",""),itsgcode_s), 
    Profile=iff(isnotempty(column_ifexists("Profile_d", "")), tostring(toint(column_ifexists("Profile_d", ""))), "")
'''
    functionAlias: 'gr_data11'
    functionParameters: 'ctrlprefix:string, ReportTime:string, showNonRequired:string'
    version: 3
  }
}
resource f5 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_mfa_evaluation'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_mfa_evaluation'
    query: '''
let reportTime = ReportTime;
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s    | project Locale_s
    | take 1
);
let localizedMessages = case(
    locale == "fr-CA", dynamic({
        "allUsersHaveMFA": "Tous les comptes d'utilisateurs natifs ont 2+ méthodes d'authentification.",
        "usersWithoutMFA": "{0} utilisateurs n'ont pas d'AMF appropriée configurée sur {1} utilisateurs totaux",
        "noUsersFound": "Aucun utilisateur trouvé",
        "evaluationError": "Erreur d'évaluation: {0}",
        "dataCollectedForAnalysis": "Données collectées pour {0} utilisateurs. L'analyse détaillée de la conformité AMF sera effectuée dans le classeur."
    }),
    dynamic({
        "allUsersHaveMFA": "Native user accounts have been identified, and all users accounts have 2+ methods of authentication enabled.",
        "usersWithoutMFA": "{0} users do not have proper MFA configured out of {1} total users",
        "noUsersFound": "No users found",
        "evaluationError": "Evaluation error: {0}",
        "dataCollectedForAnalysis": "Data collected for {0} users. Detailed MFA compliance analysis will be performed in the workbook."
    })
);
let userData = GuardrailsUserRaw_CL
| where ReportTime_s == reportTime;
let validSystemMethods = dynamic(["Fido2", "HardwareOTP"]);
let validMfaMethods = dynamic(["microsoftAuthenticatorPush", "mobilePhone", "softwareOneTimePasscode", "passKeyDeviceBound", "windowsHelloForBusiness", "fido2SecurityKey", "passKeyDeviceBoundAuthenticator", "passKeyDeviceBoundWindowsHello", "temporaryAccessPass"]);
let mfaAnalysis = userData
| extend 
    isSystemPreferredEnabled = isSystemPreferredAuthenticationMethodEnabled_b,
    systemPreferredMethodsArray = iff(
        isnotempty(systemPreferredAuthenticationMethods_s) and systemPreferredAuthenticationMethods_s startswith "[",
        parse_json(systemPreferredAuthenticationMethods_s),
        iff(isnotempty(systemPreferredAuthenticationMethods_s), pack_array(systemPreferredAuthenticationMethods_s), dynamic([]))
    ),
    methodsRegisteredArray = parse_json(methodsRegistered_s)
| extend
    hasValidSystemPreferred = iff(
        isSystemPreferredEnabled == true and isnotempty(systemPreferredMethodsArray),
        array_length(set_intersect(systemPreferredMethodsArray, validSystemMethods)) > 0,
        false
    ),
    hasMfaRegistered = isMfaRegistered_b
| extend
    validMfaMethodsCount = iff(
        hasMfaRegistered == true and isnotempty(methodsRegisteredArray),
        array_length(set_intersect(methodsRegisteredArray, validMfaMethods)),
        0
    )
| extend
    isMfaCompliant = hasValidSystemPreferred or (hasMfaRegistered == true and validMfaMethodsCount >= 2);
let summary = mfaAnalysis
| summarize 
    TotalUsers = count(),
    CompliantUsers = countif(isMfaCompliant == true),
    NonCompliantUsers = countif(isMfaCompliant == false) 
| extend 
    IsCompliant = NonCompliantUsers == 0,
    Comments = case(
        TotalUsers == 0, localizedMessages["noUsersFound"],
        NonCompliantUsers == 0, localizedMessages["allUsersHaveMFA"],
        NonCompliantUsers > 0, strcat(
            iff(locale == "fr-CA", 
                strcat(tostring(NonCompliantUsers), " utilisateurs n'ont pas d'AMF appropriée configurée sur ", tostring(TotalUsers), " utilisateurs totaux"),
                strcat(tostring(NonCompliantUsers), " users do not have proper MFA configured out of ", tostring(TotalUsers), " total users")
            ), 
            " (", tostring(NonCompliantUsers), " non-compliant, ", tostring(CompliantUsers), " compliant)"
        ),
        "Unknown error"
    );
summary
| project 
    ControlName = iff(locale == "fr-CA", "GUARDRAIL 1: PROTÉGER LES COMPTES ET LES IDENTITÉS DES UTILISATEURS", "GUARDRAIL 1: PROTECT USER ACCOUNTS AND IDENTITIES"),
    ItemName = iff(locale == "fr-CA", "Vérification de l'AMF de tous les comptes d'utilisateurs infonuagiques", "All Cloud User Accounts MFA Check"),
    ReportTime = reportTime,
    ComplianceStatus = IsCompliant,
    Comments = Comments,
    itsgcode = "IA2(1)",
    TimeGenerated = now()
'''
    functionAlias: 'gr_mfa_evaluation'
    functionParameters: 'ReportTime:string'
    version: 2
  }
}

resource f7 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_localized_strings'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_localized_strings'
    query: '''
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s
    | project Locale_s
    | take 1
);
let strings = case(
    locale == "fr-CA", dynamic({
        "workbookTitle": "Accélérateur Guardrails",
        "workbookDescription": "Sélectionnez l'heure du rapport (par défaut, la plus récente). Sélectionnez si les éléments recommandés sont affichés.",
        "mandatoryRecommended": "(M) = Obligatoire / (R) = Recommandé",
        "showRecommendedControls": "Afficher les contrôles recommandés",
        "reportTimeLabel": "Heure du rapport (UTC)",
        "yes": "Oui",
        "no": "Non",
        "guardrail1": "GUARDRAIL 1",
        "guardrail2": "GUARDRAIL 2", 
        "guardrail3": "GUARDRAIL 3",
        "guardrail4": "GUARDRAIL 4",
        "guardrail5": "GUARDRAIL 5",
        "guardrail6": "GUARDRAIL 6",
        "guardrail7": "GUARDRAIL 7",
        "guardrail8": "GUARDRAIL 8",
        "guardrail9": "GUARDRAIL 9",
        "guardrail10": "GUARDRAIL 10",
        "guardrail11": "GUARDRAIL 11",
        "guardrail12": "GUARDRAIL 12",
        "guardrail13": "GUARDRAIL 13",
        "information": "Information",
        "itemName": "Nom de l'élément",
        "comments": "Commentaires",
        "status": "État",
        "itsgControl": "Contrôle ITSG",
        "remediation": "Remédiation"
    }),
    dynamic({
        "workbookTitle": "Guardrails Accelerator",
        "workbookDescription": "Select the Report Time (Default is latest). Select whether Recommended items are shown.",
        "mandatoryRecommended": "(M) = Mandatory / (R) = Recommended",
        "showRecommendedControls": "Show Recommended Controls",
        "reportTimeLabel": "Report Time (UTC)",
        "yes": "Yes",
        "no": "No",
        "guardrail1": "GUARDRAIL 1",
        "guardrail2": "GUARDRAIL 2", 
        "guardrail3": "GUARDRAIL 3",
        "guardrail4": "GUARDRAIL 4",
        "guardrail5": "GUARDRAIL 5",
        "guardrail6": "GUARDRAIL 6",
        "guardrail7": "GUARDRAIL 7",
        "guardrail8": "GUARDRAIL 8",
        "guardrail9": "GUARDRAIL 9",
        "guardrail10": "GUARDRAIL 10",
        "guardrail11": "GUARDRAIL 11",
        "guardrail12": "GUARDRAIL 12",
        "guardrail13": "GUARDRAIL 13",
        "information": "Information",
        "itemName": "Item Name",
        "comments": "Comments", 
        "status": "Status",
        "itsgControl": "ITSG Control",
        "remediation": "Remediation"
    })
);
print locale, strings
'''
    functionAlias: 'gr_localized_strings'
    functionParameters: ''
    version: 1
  }
}

resource f6 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  name: 'gr_non_mfa_users'
  parent: guardrailsLogAnalytics
  properties: {
    category: 'gr_functions'
    displayName: 'gr_non_mfa_users'
    query: '''
let reportTime = ReportTime;
let locale = toscalar(
    GR_TenantInfo_CL
    | summarize arg_max(ReportTime_s, *) by TenantDomain_s
    | project Locale_s
    | take 1
);
let localizedMessages = case(
    locale == "fr-CA", dynamic({
        "systemPreferred": "Authentification préférée du système : ",
        "mfaRegistered": "AMF enregistrée avec les méthodes : ",
        "onlyOneMethod": "Seulement 1 méthode AMF trouvée : ",
        "atLeastTwoRequired": ". Au moins 2 requises.",
        "noValidMethods": "Aucune méthode AMF valide trouvée. Au moins 2 requises.",
        "noMfaConfigured": "Aucune AMF configurée",
        "neverSignedIn": "Jamais connecté",
        "noNonCompliantUsers": "Aucun utilisateur non conforme trouvé"
    }),
    dynamic({
        "systemPreferred": "System preferred authentication: ",
        "mfaRegistered": "MFA registered with methods: ",
        "onlyOneMethod": "Only 1 MFA method found: ",
        "atLeastTwoRequired": ". At least 2 required.",
        "noValidMethods": "No valid MFA methods found. At least 2 required.",
        "noMfaConfigured": "No MFA configured",
        "neverSignedIn": "Never Signed In",
        "noNonCompliantUsers": "No non-compliant users found"
    })
);
let userData = GuardrailsUserRaw_CL
| where ReportTime_s == reportTime;
let validSystemMethods = dynamic(["Fido2", "HardwareOTP"]);
let validMfaMethods = dynamic(["microsoftAuthenticatorPush", "mobilePhone", "softwareOneTimePasscode", "passKeyDeviceBound", "windowsHelloForBusiness", "fido2SecurityKey", "passKeyDeviceBoundAuthenticator", "passKeyDeviceBoundWindowsHello", "temporaryAccessPass"]);
let mfaAnalysis = userData
| extend 
    isSystemPreferredEnabled = isSystemPreferredAuthenticationMethodEnabled_b,
    systemPreferredMethodsArray = iff(
        isnotempty(systemPreferredAuthenticationMethods_s) and systemPreferredAuthenticationMethods_s startswith "[",
        parse_json(systemPreferredAuthenticationMethods_s),
        iff(isnotempty(systemPreferredAuthenticationMethods_s), pack_array(systemPreferredAuthenticationMethods_s), dynamic([]))
    ),
    methodsRegisteredArray = parse_json(methodsRegistered_s)
| extend
    hasValidSystemPreferred = iff(
        isSystemPreferredEnabled == true and isnotempty(systemPreferredMethodsArray),
        array_length(set_intersect(systemPreferredMethodsArray, validSystemMethods)) > 0,
        false
    ),
    hasMfaRegistered = isMfaRegistered_b
| extend
    validMfaMethodsCount = iff(
        hasMfaRegistered == true and isnotempty(methodsRegisteredArray),
        array_length(set_intersect(methodsRegisteredArray, validMfaMethods)),
        0
    )
| extend
    isMfaCompliant = hasValidSystemPreferred or (hasMfaRegistered == true and validMfaMethodsCount >= 2),
    complianceReason = case(
        hasValidSystemPreferred, strcat(tostring(localizedMessages["systemPreferred"]), strcat_array(set_intersect(systemPreferredMethodsArray, validSystemMethods), ", ")),
        hasMfaRegistered == true and validMfaMethodsCount >= 2, strcat(tostring(localizedMessages["mfaRegistered"]), strcat_array(set_intersect(methodsRegisteredArray, validMfaMethods), ", ")),
        hasMfaRegistered == true and validMfaMethodsCount == 1, strcat(tostring(localizedMessages["onlyOneMethod"]), strcat_array(set_intersect(methodsRegisteredArray, validMfaMethods), ", "), tostring(localizedMessages["atLeastTwoRequired"])),
        hasMfaRegistered == true and validMfaMethodsCount == 0, tostring(localizedMessages["noValidMethods"]),
        tostring(localizedMessages["noMfaConfigured"])
    );
let nonCompliantUsers = mfaAnalysis
| where isMfaCompliant == false
| sort by signInActivity_lastSignInDateTime_t
| project 
    DisplayName = displayName_s, 
    UserPrincipalName = userPrincipalName_s, 
    UserType = userType_s, 
    CreatedTime = iff(isnull(createdDateTime_t), "N/A", format_datetime(createdDateTime_t, 'yyyy-MM-dd HH:mm:ss')), 
    LastSignIn = iff(isnull(signInActivity_lastSignInDateTime_t), tostring(localizedMessages["neverSignedIn"]), format_datetime(signInActivity_lastSignInDateTime_t, 'yyyy-MM-dd HH:mm:ss')),
    Comments = complianceReason
| take 100;
union
(
    nonCompliantUsers
),
(
    nonCompliantUsers
    | summarize count() 
    | where count_ == 0
    | project 
        DisplayName = "N/A", 
        UserPrincipalName = "N/A", 
        UserType = "N/A", 
        CreatedTime = "N/A", 
        LastSignIn = "N/A",
        Comments = tostring(localizedMessages["noNonCompliantUsers"])
)
'''
    functionAlias: 'gr_non_mfa_users'
    functionParameters: 'ReportTime:string'
    version: 2
  }
}
resource guarrailsWorkbooks 'Microsoft.Insights/workbooks@2021-08-01' = if ((deployLAW && newDeployment) || updateWorkbook) {
  location: location
  kind: 'shared'
  name: guid('guardrails')
  properties:{
    displayName: 'Guardrails'
    serializedData: wbConfig
    version: releaseVersion
    category: 'workbook'
    sourceId: guardrailsLogAnalytics.id
  }
}

output logAnalyticsWorkspaceId string = guardrailsLogAnalytics.properties.customerId 
output logAnalyticsResourceId string = guardrailsLogAnalytics.id

