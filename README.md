Copado AI Usage Monitor
V1 - 10/30/2026

CAIUM is a LWC and supporting classes/credentials to monitor Copado AI prompt usage from within your salesforce org. It provides date range filters and a per-user and grand total prompt count for the selected time frame. 

Installation Guide
Before you start
Have these ready:

The Copado AI organization ID. This is the ID from the Copado AI platform. It is not a Salesforce org ID and not a Copado DevOps org ID.
A Copado AI API key for that organization. Do not use the Copado DevOps API key from the Account Summary tab. It will fail with a 401.
The key and the organization ID must belong to the same region as the host in the named credential, copadogpt-api.robotic.copado.com.
Never paste the API key into tickets, chat, or the named credential header.

Step 1: Set the endpoint on the named credential
Go to Setup, then Named Credentials.
Open Copado AI API and click Edit.
In the URL field, replace REPLACE_WITH_COPADO_AI_ORG_ID with your Copado AI organization ID.
Final format: https://copadogpt-api.robotic.copado.com/organizations/<your org id>
No trailing slash, no extra path.
Confirm the other settings:
External Credential: Copado AI External Credential
Enabled for Callouts: checked
Allow Formulas in HTTP Header: checked. If this is unchecked, the API key formula is not resolved and every request fails with 401 "Authentication failed".
Custom header X-Authorization with the value exactly {!$Credential.Copado_AI_EC.ApiKey}
Click Save.
Step 2: Enter the API key on the external credential
Go to Setup, then Named Credentials, and open the External Credentials tab.
Open Copado AI External Credential.
Under Principals, open CopadoAiPrincipal (type: Named Principal) and click Edit or Add for its authentication parameters.
Create or edit the authentication parameter:
Parameter name: ApiKey (exactly this, case sensitive)
Value: the Copado AI API key
Paste the key into a plain text editor first and check there are no leading or trailing spaces or line breaks. Then copy it into the value field.
Click Save.
If the parameter already exists and the dashboard fails with 401, delete the ApiKey parameter and add it again. The stored value is masked, so you cannot inspect it.

Step 3: Check permission set access to the principal
Go to Setup, then Permission Sets, and open Copado AI Activity Dashboard.
Open External Credential Principal Access.
Confirm Copado_AI_EC - CopadoAiPrincipal is enabled.
If it is missing, click Edit, move it to Enabled, and Save.
Step 4: Assign the permission set
On the Copado AI Activity Dashboard permission set, click Manage Assignments.
Click Add Assignments, select the intended users, and click Assign.
Make sure the person who will run the verification in Step 6 is included.
Step 5: Add the dashboard to a page
Open the Lightning page where the dashboard should appear, for example the Copado app home page.
Click the gear icon, then Edit Page.
In the component list, find Copado AI Activity Dashboard and drag it onto the page.
Click Save, then Activate if the page is not yet active, and assign it to the right app, profile, or app and profile as required.
Step 6: Verify
Log in as a user who has the permission set.
Open the page with the dashboard.
Confirm the summary table loads with user IDs, total prompts, and prompt limit.
Switch to the raw activity view and confirm rows load.
Change the date range and confirm the data refreshes.
