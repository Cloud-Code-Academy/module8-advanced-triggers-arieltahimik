public with sharing class OpportunityHelper {

    public static void setType(List<Opportunity> newOppList) {
        // Set default Type for new Opportunities
        for (Opportunity opp : newOppList) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }
        }
    }

    public static void validateCloseOpportunity(List<Opportunity> oldOppList) {
        // When an opportunity is deleted prevent the deletion of a closed lost/won opportunity.
        Map<Id, Account> accounts = new Map<Id, Account>([
            SELECT Id, Industry 
            FROM Account 
            WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oldOppList)
        ]);
        for(Opportunity opp : oldOppList) {
            if (opp.IsClosed) {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    public static void insertTask(List<Opportunity> newOppList) {
        // Create a new Task for newly inserted Opportunities
        List<Task> tasks = new List<Task>();
        for (Opportunity opp : newOppList){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tasks.add(tsk);
        }
        insert tasks;
    }

    public static void updateDescriptionFromStage(List<Opportunity> newOppList, Map<Id,Opportunity> oldOppMap) {
        // Append Stage changes in Opportunity Description
        for (Opportunity opp: newOppList ) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);
            if (opp.StageName != oldOpp.StageName) {
                opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            }
        }
    }

    public static void notifyOwnersOpportunityDeleted(List<Opportunity> oldOppList) {
        /*
        - Sends an email notification to the owner of the Opportunity when it gets deleted.
        - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
        */
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Email FROM User]);
        for (Opportunity opp : oldOppList){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();            
            //String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            User owner = userMap.get(opp.OwnerId);
            String[] toAddresses = new List<String>{ owner.Email };
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    public static void assignPrimaryContact(Map<Id,Opportunity> newOppMap) {
        /*
        assignPrimaryContact:
        - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
        - Only updates the Opportunities that don't already have a primary contact.
        */

        // Get all Account Ids from the opportunities
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : newOppMap.values()) {
            accountIds.add(opp.AccountId);  
        }

        // Query contacts from accountIds with Title 'VP Sales'
        List<Contact> primaryContacts = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :accountIds];
        Map<Id, Contact> accIdToConMap = new Map<Id, Contact>();
        for (Contact con : primaryContacts) {
            accIdToConMap.put(con.AccountId,con);
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : newOppMap.values()) {            
            if (opp.Primary_Contact__c == null) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                Contact primaryContact = accIdToConMap.get(opp.AccountId);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                //oppToUpdate.Primary_Contact__c = accIdToConMap.get(opp.AccountId).Id; // The 2 lines above, combined.
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();    
    }

    public static void amountValidation(List<Opportunity> newOppList) {
        for (Opportunity opp : newOppList) {
            if (opp.Amount <= 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    public static void deleteCloseWonOpportunity(List<Opportunity> oldOppList) {
        // When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oldOppList)]);
        for (Opportunity opp : oldOppList) {
            if ((opp.StageName == 'Closed Won' && accounts.get(opp.AccountId).Industry == 'Banking')) {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    public static void setPrimaryContact(List<Opportunity> newOppList) {
        // When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.

        // Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : newOppList){
            accountIds.add(opp.AccountId);
        }
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);

        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact con : contacts.values()) {
            if (!accountIdToContact.containsKey(con.AccountId)) {
                accountIdToContact.put(con.AccountId, con);
            }
        }

        for(Opportunity opp : newOppList){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }
}