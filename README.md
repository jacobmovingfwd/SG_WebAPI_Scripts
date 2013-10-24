## SendGrid WebAPI Scripts

These scripts perform a number of tasks using the [SendGrid WebAPI](http://sendgrid.com/docs/API_Reference/Web_API/index.html "SG WebAPI").

#### Requirements
All of these scripts require:
* A [Credential](http://sendgrid.com/docs/User_Guide/multiple_credentials.html "SG Credentials") that has API permissions.
* The folder ./logs , for logging logs.

#### Script Description
* **Address Match & Clear:** This takes a CSV with email addresses in the first column, and removes each address from the supression lists you select.
* **Domain Match & Clear:** This takes a provided domain, and removes all addresses at that domain from the suppression lists you select.
* **Reason Match & Clear:** This takes a string, and removes all suppression list entries that include that string in the *Reason*. This include partial matches, so use with **caution**.
* **Subuser Event Update:** This runs through all of an account's subusers, and updates them to the new Version 3 of the [Event Webhook](http://sendgrid.com/docs/API_Reference/Webhooks/event.html "SG Event Webhook"). This can be easily modified to hard-set other parameters for the Event Webhook for all subusers.
* **Suppression Get:** This downloads all of the selected suppression lists for an account, safely accessing the API with sleeps, and tar-zips the result. This is useful if an account's Suppression List is too big to load on the site.
* **Unsubscribe Import:** This takes a CSV with email addresses in the first column, and adds each address to the account's Unsubscribe list. 

-----
Please feel free to PR additional scripts as you make them.

Please make sure all scripts are clear or any account-identifying information, follow the logging guide, and have sleeps.